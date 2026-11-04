// w8_ev_can - vehicle control unit (VCU) of a rear-wheel-drive electric car with one motor
// per rear wheel (Sea workload W8, DESIGN.md §2.16.4).
//
// Every 10 ms the VCU reads two accelerator pedal tracks and the steering angle by ADC,
// turns them into a total torque request and a yaw-rate based left/right torque split, and
// sends one torque command to each motor controller (MCU) over TWAI (CAN, 500 kbit/s). It
// listens to both MCUs' feedback and to a yaw-rate sensor (IMU), watches for missing
// feedback and implausible pedal tracks, and runs a small state machine:
//   INIT -> RUN, RUN -> FAULT_FB / FAULT_APPS, and back to RUN once the fault is gone and
//   the pedal is released.
//
// Hardware: ESP32, TWAI TX on GPIO 21 and RX on GPIO 22 (through a transceiver in the car),
// pedal track A on GPIO 36, track B on GPIO 39, steering sensor on GPIO 34 (12-bit ADC),
// mode strap on GPIO 25: grounded = car mode, open = bench mode. In bench mode the driver
// runs without acknowledgement and asks for self-reception, and every frame received is
// printed over Serial as a log line, so a bare board with TX wired to RX logs its own bus.
//
// The same source also compiles, unmodified, on the Mac against the W8 host mock. So it
// uses only fixed-width integer types, bool and char, integer arithmetic with truncating
// division, uint32_t clock arithmetic, and declares every function before its first use.
// The message layouts and pack/unpack helpers live in w8_can_msgs.h.

#include <inttypes.h>
#include <stdio.h>
#include <driver/twai.h>
#include "w8_can_msgs.h"

// ---- Pins (TWAI TX/RX are passed to the driver as GPIO_NUM_21/GPIO_NUM_22 in setup()) ----
static const uint8_t PIN_PEDAL_A = 36;
static const uint8_t PIN_PEDAL_B = 39;
static const uint8_t PIN_STEER   = 34;
static const uint8_t PIN_MODE    = 25;

// ---- Timing ----
static const uint32_t STEP_US       = 10000;  // control period, 10 ms
static const uint32_t FB_TIMEOUT_US = 50000;  // feedback older than this is a timeout

// ---- Run-time state ----
static bool     twaiOk = false;    // driver installed and started
static bool     bench  = false;    // bench mode (strap open)
static uint32_t nextStep = 0;      // micros() value of the next control step
static uint32_t k = 0;             // control step number (step 1 is the first)

// 64-bit microseconds since boot, kept across micros() wraps.
static uint32_t lastNow = 0;
static uint64_t uptimeUs = 0;

// Last valid feedback of each motor (index 0 left, 1 right).
static bool     fbSeen[2]  = {false, false};
static uint32_t fbTime[2]  = {0, 0};
static int32_t  fbTorque[2] = {0, 0};   // TorqueAct, 0.1 N·m (kept for completeness)
static int32_t  fbSpeed[2]  = {0, 0};   // Speed, rev/min
static bool     infoShown[2] = {false, false};

// Last yaw rate from the IMU, mrad/s.
static int32_t rMeas = 0;

// Control law memory.
static uint8_t  state   = W8_ST_INIT;
static int32_t  appsBad = 0;       // consecutive implausible pedal steps, saturating at 10
static int32_t  okSteps = 0;       // consecutive steps without a feedback timeout, saturating at 10
static int32_t  cmdL    = 0;       // rate-limited torque commands, 0.1 N·m
static int32_t  cmdR    = 0;
static uint8_t  hbCount = 0;       // heartbeat counter (first heartbeat sends 1)
static uint32_t txFail  = 0;       // transmits the driver refused (never expected)

// Serial line buffer.
static char line[96];

// ---- Helpers ----

// Advance the 64-bit uptime to the micros() value now. Called once per loop(), which runs
// far more often than once per 71-minute wrap of the 32-bit counter.
static void updateUptime(uint32_t now) {
    uptimeUs += (uint32_t)(now - lastNow);
    lastNow = now;
}

// The uptime split into whole seconds and the remaining microseconds.
static void uptimeParts(uint32_t *sec, uint32_t *usec) {
    *sec  = (uint32_t)(uptimeUs / 1000000u);
    *usec = (uint32_t)(uptimeUs % 1000000u);
}

// Name of a VCU state, as printed on state changes.
static const char *stateName(uint8_t s) {
    switch (s) {
    case W8_ST_INIT:     return "INIT";
    case W8_ST_RUN:      return "RUN";
    case W8_ST_FAULT_FB: return "FAULT_FB";
    default:             return "FAULT_APPS";
    }
}

// Queue one frame for transmission without waiting; a refusal is only counted.
static void sendFrame(twai_message_t *m) {
    if (bench) {
        m->self = 1;                    // bench: receive our own frame back
    }
    if (twai_transmit(m, 0) != ESP_OK) {
        txFail++;
    }
}

// Print a received frame as a bench log line: (sssssssssss.uuuuuu) twai0 ID#DATA
static void printFrame(const twai_message_t &m) {
    uint32_t sec, usec;
    uptimeParts(&sec, &usec);
    int n = snprintf(line, sizeof line, "(%010" PRIu32 ".%06" PRIu32 ") twai0 %03" PRIX32 "#",
                     sec, usec, (uint32_t)m.identifier);
    if (m.rtr) {
        n += snprintf(line + n, sizeof line - (size_t)n, "R");
    } else {
        uint32_t dlc = m.data_length_code;
        if (dlc > 8u) {
            dlc = 8u;                   // never more than the eight data bytes
        }
        for (uint32_t i = 0; i < dlc; ++i) {
            n += snprintf(line + n, sizeof line - (size_t)n, "%02" PRIX32, (uint32_t)m.data[i]);
        }
    }
    snprintf(line + n, sizeof line - (size_t)n, "\n");
    Serial.print(line);
}

// Car mode: take what the law needs from a received frame; everything else is ignored.
static void handleFrame(const twai_message_t &m, uint32_t now) {
    if (m.extd) {
        return;                         // the car uses 11-bit identifiers only
    }
    uint32_t id = m.identifier;

    if ((id == W8_ID_MCU_FB_L || id == W8_ID_MCU_FB_R) && !m.rtr) {
        // Motor feedback: only a complete frame with a good checksum counts.
        if (m.data_length_code != W8_DLC_MCU_FB) {
            return;
        }
        if (m.data[7] != w8_checksum(id, m.data, W8_DLC_MCU_FB)) {
            return;
        }
        int idx = (id == W8_ID_MCU_FB_L) ? 0 : 1;
        fbTorque[idx] = w8_get_be16s(&m.data[0]);
        fbSpeed[idx]  = w8_get_be16s(&m.data[2]);
        fbTime[idx]   = now;
        fbSeen[idx]   = true;
    } else if (id == W8_ID_IMU_YAW && !m.rtr) {
        if (m.data_length_code == W8_DLC_IMU_YAW) {
            rMeas = w8_get_le16s(&m.data[0]);
        }
    } else if ((id == W8_ID_MCU_INFO_L || id == W8_ID_MCU_INFO_R) && !m.rtr) {
        // The MCU's answer to our remote request: report it once per motor.
        int idx = (id == W8_ID_MCU_INFO_L) ? 0 : 1;
        if (infoShown[idx] || m.data_length_code != W8_DLC_MCU_INFO) {
            return;
        }
        infoShown[idx] = true;
        uint32_t fw = w8_get_u16le(&m.data[0]);
        uint32_t serialNo = w8_get_u16le(&m.data[2]) | (w8_get_u16le(&m.data[4]) << 16);
        snprintf(line, sizeof line, "# MCU %c fw %" PRIu32 ".%02" PRIu32 " serial %08" PRIX32 "\n",
                 idx == 0 ? 'L' : 'R', fw >> 8, fw & 0xFFu, serialNo);
        Serial.print(line);
    }
}

// Absolute value of a small int32_t.
static int32_t absVal(int32_t x) {
    return x < 0 ? -x : x;
}

// One control step at time now (steps 1-11 of DESIGN.md §2.16.4).
static void controlStep(uint32_t now) {
    int32_t rawA = analogRead(PIN_PEDAL_A);
    int32_t rawB = analogRead(PIN_PEDAL_B);
    int32_t rawS = analogRead(PIN_STEER);

    // 1. Pedal: two tracks with different offsets and gains, cross-checked, then a deadband.
    int32_t pA = w8_clamp32(w8_tdiv32((rawA - 410) * 1000, 3276), 0, 1000);
    int32_t pB = w8_clamp32(w8_tdiv32((rawB - 205) * 1000, 1638), 0, 1000);
    bool implausible = absVal(pA - pB) > 100;
    if (implausible) {
        appsBad = w8_clamp32(appsBad + 1, 0, 10);
    } else {
        appsBad = 0;
    }
    int32_t p = (pA + pB) / 2;                       // both non-negative
    int32_t pd = 0;                                  // pedal after the deadband, 0 ... 1000
    if (p >= 50) {
        pd = (p - 50) * 1000 / 950;
    }

    // 2. Steering: road-wheel angle in mrad, positive left.
    int32_t delta = w8_tdiv32((rawS - 2048) * 350, 2048);

    // 3. Feedback timeouts, and the run of steps without one.
    bool toL = !fbSeen[0] || (uint32_t)(now - fbTime[0]) > FB_TIMEOUT_US;
    bool toR = !fbSeen[1] || (uint32_t)(now - fbTime[1]) > FB_TIMEOUT_US;
    if (toL || toR) {
        okSteps = 0;
    } else {
        okSteps = w8_clamp32(okSteps + 1, 0, 10);
    }

    // 4. Vehicle speed from the two motor speeds (0.01 m/s).
    int32_t vMm = w8_tdiv32((fbSpeed[0] + fbSpeed[1]) * 1745, 1000);
    int32_t vCs = w8_tdiv32(vMm, 10);

    // 5. State machine: only the current state's rule is tested, one transition at most.
    uint8_t next = state;
    if (state == W8_ST_INIT) {
        if (k >= 50u && !toL && !toR && appsBad == 0 && pd == 0) {
            next = W8_ST_RUN;
        }
    } else if (state == W8_ST_RUN) {
        if (toL || toR) {
            next = W8_ST_FAULT_FB;
        } else if (appsBad == 10) {
            next = W8_ST_FAULT_APPS;
        }
    } else if (state == W8_ST_FAULT_FB) {
        if (okSteps == 10 && pd == 0) {
            next = W8_ST_RUN;
        }
    } else {
        if (appsBad == 0 && pd == 0) {
            next = W8_ST_RUN;
        }
    }
    if (next != state) {
        state = next;
        uint32_t sec, usec;
        uptimeParts(&sec, &usec);
        snprintf(line, sizeof line, "# %" PRIu32 ".%06" PRIu32 " state %s\n",
                 sec, usec, stateName(state));
        Serial.print(line);
    }
    bool run = (state == W8_ST_RUN);

    // 6. Torque request for both motors together (0.1 N·m); a light coast regeneration.
    int32_t tReq = 0;
    if (run) {
        if (pd > 0) {
            tReq = 2 * pd;
        } else if (vCs > 300) {
            tReq = -200;
        }
    }

    // 7. Yaw-rate demand of a neutral-steering car (mrad/s), limited to 8 m/s^2 lateral.
    int32_t rDes = (int32_t)w8_tdiv64((int64_t)vCs * 10 * delta, 2400);
    bool yawLimit = false;
    if (vCs > 100) {
        int32_t rLim = w8_tdiv32(800000, vCs);
        int32_t limited = w8_clamp32(rDes, -rLim, rLim);
        yawLimit = (limited != rDes);
        rDes = limited;
    }

    // 8. Torque split, right minus left: feed-forward on the demand plus yaw-error feedback.
    int32_t dT = 0;
    if (run) {
        dT = w8_clamp32(w8_tdiv32(200 * rDes + 600 * (rDes - rMeas), 1000), -400, 400);
    }

    // 9. Per-wheel targets.
    int32_t tR = w8_clamp32(w8_tdiv32(tReq + dT, 2), -1000, 1000);
    int32_t tL = w8_clamp32(w8_tdiv32(tReq - dT, 2), -1000, 1000);

    // 10. Rate limit: at most 5 N·m change per step.
    cmdL += w8_clamp32(tL - cmdL, -50, 50);
    cmdR += w8_clamp32(tR - cmdR, -50, 50);

    // 11. Transmit this step's frames, all with the same 4-bit counter.
    uint8_t counter = (uint8_t)(k & 0x0Fu);
    uint8_t enable  = (state == W8_ST_INIT) ? 0 : 1;
    uint8_t cmdByte = (uint8_t)(counter | (enable << 4) | (state << 5));

    twai_message_t m = {};
    m.identifier = W8_ID_TQ_CMD_L;
    m.data_length_code = W8_DLC_TQ_CMD;
    w8_put_le16(&m.data[0], cmdL);
    m.data[2] = cmdByte;
    m.data[3] = w8_checksum(W8_ID_TQ_CMD_L, m.data, W8_DLC_TQ_CMD);
    sendFrame(&m);

    m = {};
    m.identifier = W8_ID_TQ_CMD_R;
    m.data_length_code = W8_DLC_TQ_CMD;
    w8_put_le16(&m.data[0], cmdR);
    m.data[2] = cmdByte;
    m.data[3] = w8_checksum(W8_ID_TQ_CMD_R, m.data, W8_DLC_TQ_CMD);
    sendFrame(&m);

    m = {};
    m.identifier = W8_ID_VCU_DRIVER;
    m.data_length_code = W8_DLC_VCU_DRIVER;
    w8_put_le16(&m.data[0], p | ((int32_t)state << 10) | ((int32_t)counter << 12));
    w8_put_le16(&m.data[2], tReq);
    w8_put_le16(&m.data[4], delta);
    w8_put_le16(&m.data[6], vCs);
    sendFrame(&m);

    m = {};
    m.identifier = W8_ID_VCU_YAW;
    m.data_length_code = W8_DLC_VCU_YAW;
    w8_put_le16(&m.data[0], rDes);
    w8_put_le16(&m.data[2], rMeas);
    w8_put_le16(&m.data[4], dT);
    m.data[6] = (uint8_t)(counter | ((toL ? 1 : 0) << 4) | ((toR ? 1 : 0) << 5) |
                          ((implausible ? 1 : 0) << 6) | ((yawLimit ? 1 : 0) << 7));
    m.data[7] = w8_checksum(W8_ID_VCU_YAW, m.data, W8_DLC_VCU_YAW);
    sendFrame(&m);

    // Heartbeat every tenth step.
    if (k % 10u == 0u) {
        hbCount = (uint8_t)(hbCount + 1u);
        m = {};
        m.identifier = W8_ID_VCU_HB;
        m.data_length_code = W8_DLC_VCU_HB;
        m.data[0] = state;
        m.data[1] = hbCount;
        sendFrame(&m);
    }

    // Once a second (from step 5): ask both MCUs for their firmware and serial number.
    if (k % 100u == 5u) {
        m = {};
        m.identifier = W8_ID_MCU_INFO_L;
        m.rtr = 1;
        m.data_length_code = W8_DLC_MCU_INFO;
        sendFrame(&m);

        m = {};
        m.identifier = W8_ID_MCU_INFO_R;
        m.rtr = 1;
        m.data_length_code = W8_DLC_MCU_INFO;
        sendFrame(&m);
    }
}

void setup() {
    Serial.begin(921600);
    pinMode(PIN_MODE, INPUT_PULLUP);
    bench = (digitalRead(PIN_MODE) == HIGH);
    analogReadResolution(12);

    // TWAI at 500 kbit/s; on the bench no other node acknowledges, so run without ACK.
    twai_mode_t mode = bench ? TWAI_MODE_NO_ACK : TWAI_MODE_NORMAL;
    twai_general_config_t g = TWAI_GENERAL_CONFIG_DEFAULT(GPIO_NUM_21, GPIO_NUM_22, mode);
    g.tx_queue_len = 16;
    g.rx_queue_len = 32;
    twai_timing_config_t t = TWAI_TIMING_CONFIG_500KBITS();
    twai_filter_config_t f = TWAI_FILTER_CONFIG_ACCEPT_ALL();
    if (twai_driver_install(&g, &t, &f) != ESP_OK || twai_start() != ESP_OK) {
        Serial.print("# twai start failed\n");
        return;                         // twaiOk stays false: loop() does nothing
    }
    twaiOk = true;

    Serial.print(bench ? "# w8_ev_can 1.0 bench\n" : "# w8_ev_can 1.0 car\n");
    nextStep = (uint32_t)micros() + STEP_US;
    k = 0;
}

void loop() {
    if (!twaiOk) {
        return;
    }
    uint32_t now = (uint32_t)micros();
    updateUptime(now);

    // Handle every frame already received, before any step that follows them.
    twai_message_t m = {};
    while (twai_receive(&m, 0) == ESP_OK) {
        if (bench) {
            printFrame(m);
        } else {
            handleFrame(m, now);
        }
    }

    // Run the control step when its time has come.
    if ((int32_t)(now - nextStep) >= 0) {
        k++;
        controlStep(now);
        nextStep += STEP_US;
    }
}
