// mock_twai.cpp - the TWAI driver mock and the simulated CAN bus of w8sim (Sea DESIGN.md
// §2.16.3 "Frame length on the wire", §2.16.5 "The bus", §2.16.7 "Car log").
//
// One classic CAN bus at 500 kbit/s (2 µs per bit). Every node has a FIFO transmit queue;
// when the bus is idle the queue heads arbitrate by (identifier << 1) | RTR, the smallest
// winning. A frame occupies the bus for its exact length L in bits (CRC-15 and stuff bits
// included), i.e. 2·L µs, followed by the 3-bit intermission (6 µs). At its end it is
// delivered to the other nodes and written to the bus log. There are no bit errors, error
// frames or retransmissions.

#include <deque>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include "driver/twai.h"
#include "sim.h"
#include "model.h"

// Base of the log's timestamps: 2026-11-04 00:00:00 UTC in seconds (L-nk).
static const int64_t LOG_T0_S = 1793750400;

// Transmit queue capacities of the model nodes (the VCU's comes from twai_driver_install).
static const size_t MODEL_TX_QUEUE_LEN = 8;

// ---- Driver state of the VCU's TWAI controller ----
static bool        drv_installed = false;
static bool        drv_started   = false;
static twai_mode_t drv_mode      = TWAI_MODE_NORMAL;   // recorded; the bus model needs no ACK
static size_t      drv_tx_len    = 0;
static size_t      drv_rx_len    = 0;

// ---- Bus state ----
static std::deque<sim_frame> tx_queue[SIM_NODES];  // FIFO per node
static std::deque<sim_frame> vcu_rx;               // the VCU's receive queue
static uint32_t rx_lost = 0;                       // frames lost at a full receive queue

static bool      bus_busy = false;      // a frame is on the bus
static sim_frame bus_frame;             // that frame
static int       bus_node = 0;          // and its sender
static int64_t   bus_end = 0;           // its end time
static int64_t   bus_idle_at = 0;       // the bus is idle from this time on

static FILE *log_file = nullptr;

// ---- Frame length on the wire (§2.16.3) ----

// The number of bit times L a frame occupies on the bus: the unstuffed bits SOF, identifier,
// RTR, IDE, r0, DLC, data and CRC-15 (n0 = 34 + 8·D), the stuff bits s counted over them, and
// 10 bits of CRC delimiter, ACK slot and delimiter and end of frame.
static int frame_bits(const sim_frame *f) {
    uint8_t bits[34 + 64];
    int n = 0;
    bits[n++] = 0;                                      // SOF
    for (int i = 10; i >= 0; --i) {
        bits[n++] = (uint8_t)((f->id >> i) & 1u);       // identifier, MSB first
    }
    bits[n++] = f->rtr ? 1 : 0;                         // RTR
    bits[n++] = 0;                                      // IDE (standard frame)
    bits[n++] = 0;                                      // r0
    for (int i = 3; i >= 0; --i) {
        bits[n++] = (uint8_t)((f->dlc >> i) & 1u);      // DLC code
    }
    if (!f->rtr) {
        for (int b = 0; b < f->dlc; ++b) {
            for (int i = 7; i >= 0; --i) {
                bits[n++] = (uint8_t)((f->data[b] >> i) & 1u);
            }
        }
    }
    // CRC-15 over SOF ... last data bit, polynomial 0x4599, register starting at 0.
    uint32_t c = 0;
    for (int i = 0; i < n; ++i) {
        uint32_t nx = (uint32_t)bits[i] ^ ((c >> 14) & 1u);
        c = (c << 1) & 0x7FFFu;
        if (nx != 0) {
            c ^= 0x4599u;
        }
    }
    for (int i = 14; i >= 0; --i) {
        bits[n++] = (uint8_t)((c >> i) & 1u);
    }
    // Stuff bits: after five equal bits one bit of the opposite value, which itself starts
    // the next run (a stuff bit after the last CRC bit counts too).
    int stuff = 0;
    int prev = -1;
    int run = 0;
    for (int i = 0; i < n; ++i) {
        if (bits[i] == prev) {
            ++run;
        } else {
            prev = bits[i];
            run = 1;
        }
        if (run == 5) {
            ++stuff;
            prev = 1 - prev;
            run = 1;
        }
    }
    return n + stuff + 10;
}

// ---- The bus log ----

void sim_bus_open_log(const char *path) {
    if (path == nullptr) {
        return;
    }
    log_file = fopen(path, "wb");
    if (log_file == nullptr) {
        sim_fatal("cannot write the bus log");
    }
}

void sim_bus_close_log(void) {
    if (log_file == nullptr) {
        return;
    }
    bool bad = ferror(log_file) != 0;
    if (fclose(log_file) != 0) {
        bad = true;
    }
    log_file = nullptr;
    if (bad) {
        sim_fatal("cannot write the bus log");
    }
}

// One candump -L line: (ssssssssss.uuuuuu) can0 ID#DATA, the time being T0 + the frame's end.
static void log_frame(const sim_frame *f, int64_t t_end) {
    if (log_file == nullptr) {
        return;
    }
    char line[64];
    int n = snprintf(line, sizeof line, "(%010" PRId64 ".%06" PRId64 ") can0 %03" PRIX32 "#",
                     LOG_T0_S + t_end / 1000000, t_end % 1000000, f->id);
    if (f->rtr) {
        n += snprintf(line + n, sizeof line - (size_t)n, "R");
    } else {
        for (int i = 0; i < f->dlc; ++i) {
            n += snprintf(line + n, sizeof line - (size_t)n, "%02" PRIX32, (uint32_t)f->data[i]);
        }
    }
    n += snprintf(line + n, sizeof line - (size_t)n, "\n");
    if (fwrite(line, 1, (size_t)n, log_file) != (size_t)n) {
        sim_fatal("cannot write the bus log");
    }
}

// ---- Delivery and arbitration ----

// Put a frame into the VCU's receive queue; a frame arriving at a full queue is lost.
static void vcu_receive(const sim_frame *f) {
    if (!drv_started) {
        return;     // a stopped controller takes no part in the bus
    }
    if (vcu_rx.size() >= drv_rx_len) {
        ++rx_lost;
        return;
    }
    vcu_rx.push_back(*f);
}

// The frame on the bus has ended at t: deliver it to every other node and log it.
static void bus_deliver(int64_t t) {
    bus_busy = false;
    log_frame(&bus_frame, t);
    if (bus_node == SIM_NODE_VCU) {
        // The model nodes listen only in the car; on the bench the VCU hears itself when the
        // frame asked for self-reception.
        if (!sim_cfg.bench) {
            sim_model_receive(&bus_frame, t);
        } else if (bus_frame.self) {
            vcu_receive(&bus_frame);
        }
    } else {
        vcu_receive(&bus_frame);
    }
}

void sim_bus_arbitrate(int64_t t) {
    if (bus_busy || t < bus_idle_at) {
        return;
    }
    int win = -1;
    uint32_t best = 0;
    for (int node = 0; node < SIM_NODES; ++node) {
        if (tx_queue[node].empty()) {
            continue;
        }
        const sim_frame &h = tx_queue[node].front();
        uint32_t key = (h.id << 1) | (h.rtr ? 1u : 0u);    // a data frame beats a remote one
        if (win < 0 || key < best) {
            win = node;
            best = key;
        }
    }
    if (win < 0) {
        return;
    }
    bus_frame = tx_queue[win].front();
    tx_queue[win].pop_front();
    bus_node = win;
    bus_busy = true;
    bus_end = t + 2 * (int64_t)frame_bits(&bus_frame);     // 2 µs per bit
    bus_idle_at = bus_end + 6;                              // 3-bit intermission
}

void sim_bus_end_and_arbitrate(int64_t t) {
    if (bus_busy && bus_end == t) {
        bus_deliver(t);
    }
    sim_bus_arbitrate(t);
}

int64_t sim_bus_next_event(int64_t from) {
    if (bus_busy) {
        return bus_end >= from ? bus_end : from;
    }
    if (bus_idle_at >= from) {
        for (int node = 0; node < SIM_NODES; ++node) {
            if (!tx_queue[node].empty()) {
                return bus_idle_at;
            }
        }
    }
    return INT64_MAX;
}

void sim_bus_enqueue(int node, const sim_frame *f) {
    if (tx_queue[node].size() >= MODEL_TX_QUEUE_LEN) {
        sim_fatal("a model node's transmit queue overflowed");
    }
    tx_queue[node].push_back(*f);
}

uint32_t sim_bus_rx_lost(void) {
    return rx_lost;
}

// ---- The driver API the sketch calls ----

esp_err_t twai_driver_install(const twai_general_config_t *g_config,
                              const twai_timing_config_t *t_config,
                              const twai_filter_config_t *f_config) {
    if (g_config == nullptr || t_config == nullptr || f_config == nullptr) {
        return ESP_ERR_INVALID_ARG;
    }
    if (drv_installed) {
        return ESP_ERR_INVALID_STATE;
    }
    // The bit rate must be the bus's 500 kbit/s: quanta / (1 + tseg_1 + tseg_2).
    uint32_t quanta_per_bit = 1u + t_config->tseg_1 + t_config->tseg_2;
    if (t_config->quanta_resolution_hz % quanta_per_bit != 0 ||
        t_config->quanta_resolution_hz / quanta_per_bit != 500000u) {
        return ESP_ERR_INVALID_ARG;
    }
    drv_mode = g_config->mode;
    drv_tx_len = g_config->tx_queue_len;
    drv_rx_len = g_config->rx_queue_len;
    drv_installed = true;
    return ESP_OK;
}

esp_err_t twai_start(void) {
    if (!drv_installed || drv_started) {
        return ESP_ERR_INVALID_STATE;
    }
    drv_started = true;
    return ESP_OK;
}

esp_err_t twai_transmit(const twai_message_t *message, TickType_t ticks_to_wait) {
    if (ticks_to_wait != 0) {
        sim_fatal("unsupported call: twai_transmit with a nonzero wait");
    }
    if (!drv_started) {
        return ESP_ERR_INVALID_STATE;
    }
    if (message == nullptr || message->data_length_code > 8 || message->extd) {
        // An extended identifier is a deliberate departure from the real driver (§2.16.5).
        return ESP_ERR_INVALID_ARG;
    }
    if (tx_queue[SIM_NODE_VCU].size() >= drv_tx_len) {
        return ESP_ERR_TIMEOUT;
    }
    sim_frame f = {};
    f.id = message->identifier & 0x7FFu;
    f.rtr = message->rtr ? 1 : 0;
    f.dlc = message->data_length_code;
    f.self = message->self ? 1 : 0;
    if (!f.rtr) {
        memcpy(f.data, message->data, f.dlc);
    }
    tx_queue[SIM_NODE_VCU].push_back(f);
    return ESP_OK;
}

esp_err_t twai_receive(twai_message_t *message, TickType_t ticks_to_wait) {
    if (ticks_to_wait != 0) {
        sim_fatal("unsupported call: twai_receive with a nonzero wait");
    }
    if (vcu_rx.empty()) {
        return ESP_ERR_TIMEOUT;
    }
    const sim_frame &f = vcu_rx.front();
    *message = {};
    message->rtr = f.rtr;
    message->identifier = f.id;
    message->data_length_code = f.dlc;
    if (!f.rtr) {
        memcpy(message->data, f.data, f.dlc);
    }
    vcu_rx.pop_front();
    return ESP_OK;
}
