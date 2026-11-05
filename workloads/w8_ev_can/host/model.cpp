// model.cpp - the motor controllers, the yaw-rate sensor, the vehicle, the driver's traces
// and the deliberate faults of w8sim (Sea DESIGN.md §2.16.6).
//
// Integer arithmetic only (L-nf): int64_t state, tdiv = C++'s division truncated toward
// zero (always with a positive divisor here), clamp. Units in the comments: t in µs,
// torque T_act in mN·m, commands in 0.1 N·m, speed v in µm/s, yaw rate r in µrad/s, motor
// speed n in rev/min, forces in mN.

#include <vector>
#include "sim.h"
#include "model.h"
#include "../w8_ev_can/w8_can_msgs.h"

// ---- Small integer helpers ----

static int64_t tdiv(int64_t a, int64_t b) {
    return w8_tdiv64(a, b);
}

static int64_t clamp(int64_t x, int64_t lo, int64_t hi) {
    return w8_clamp64(x, lo, hi);
}

static int64_t iabs(int64_t x) {
    return x < 0 ? -x : x;
}

static int64_t imax(int64_t a, int64_t b) {
    return a > b ? a : b;
}

static int64_t imin(int64_t a, int64_t b) {
    return a < b ? a : b;
}

// ---- Generators: 32-bit xorshift, one per noise source ----

static const uint32_t SEED_ADC = 0x1D872B41u;
static const uint32_t SEED_MOT = 0x6C8E9CF5u;
static const uint32_t SEED_IMU = 0x3A1F4B27u;
static const uint32_t SEED_BUS = 0x5BD1E995u;

static uint32_t gen_adc, gen_mot, gen_imu, gen_bus;

static uint32_t gen_next(uint32_t *x) {
    uint32_t v = *x;
    v ^= v << 13;
    v ^= v >> 17;
    v ^= v << 5;
    *x = v;
    return v;
}

// An integer in -k ... k.
static int64_t uniform(uint32_t *g, int64_t k) {
    return (int64_t)(gen_next(g) % (uint32_t)(2 * k + 1)) - k;
}

// ---- Traces: piecewise linear in t_ms ----

struct trace_point {
    int64_t t_ms;
    int64_t y;
};

// Pedal travel q in per mille.
static const trace_point TRACE_Q[] = {
    {0, 0}, {1000, 0}, {1500, 600}, {3500, 600}, {4000, 90}, {12000, 90}, {12500, 0}, {16000, 0},
    {16500, 300}, {17500, 300}, {18000, 90}, {30000, 90}, {31000, 0}, {33000, 0}, {34000, 1000},
    {42000, 1000}, {43000, 0}, {48000, 0}, {48500, 90}, {74000, 90}, {74500, 0}, {78000, 0},
    {78500, 95}, {92000, 95}, {92500, 250}, {97000, 250}, {97500, 0}, {100000, 0},
    {100500, 300}, {102000, 300}, {102500, 90}, {115000, 90}, {116000, 0}, {120000, 0},
};

// Road-wheel steering angle delta_true in mrad, positive left.
static const trace_point TRACE_DELTA[] = {
    {0, 0}, {18000, 0}, {19000, 80}, {27000, 80}, {28000, 0}, {50000, 0}, {51000, 40},
    {53000, -40}, {55000, 40}, {57000, -40}, {59000, 40}, {61000, -40}, {63000, 40},
    {65000, -40}, {67000, 40}, {69000, -40}, {70000, 0}, {82000, 0}, {83000, -40},
    {89000, -40}, {90000, 0}, {106000, 0}, {107000, 30}, {113000, 30}, {114000, 0},
    {120000, 0},
};

// y_i + tdiv((y_(i+1) - y_i)·(t_ms - t_i), t_(i+1) - t_i) for t_i <= t_ms < t_(i+1); the last
// value after the last breakpoint.
static int64_t trace_value(const trace_point *p, size_t count, int64_t t_ms) {
    for (size_t i = 0; i + 1 < count; ++i) {
        if (p[i].t_ms <= t_ms && t_ms < p[i + 1].t_ms) {
            return p[i].y + tdiv((p[i + 1].y - p[i].y) * (t_ms - p[i].t_ms),
                                 p[i + 1].t_ms - p[i].t_ms);
        }
    }
    return p[count - 1].y;
}

// ---- Parameters ----

static const int64_t VEH_MASS_KG       = 900;
static const int64_t ROLL_RES_MN       = 105948;        // Crr·m·g
static const int64_t WHEELBASE_UM      = 2400000;
static const int64_t UNDERSTEER_DIV    = 260416667;     // v² [µm²/s²] / this = L·v²/v_ch² [µm]
static const int64_t YAW_RELAX_TICKS   = 150;
static const int64_t YAW_MOMENT_DIV    = 1600;          // ΔF·0.75 m / 1200 kg·m², per 1 ms
static const int64_t MOTOR_PEAK        = 1000;          // 0.1 N·m
static const int64_t MOTOR_POWER_K     = 2864789;       // T_pow = this / |n|, 0.1 N·m
static const int64_t MOTOR_FADE_START  = 8000;          // rev/min
static const int64_t MOTOR_FADE_END    = 9000;          // rev/min
static const int64_t MOTOR_LAG_TICKS   = 8;
static const int64_t K_MOTORING        = 1537437;
static const int64_t K_GENERATING      = 1816442;
static const int64_t RPM_PER_UMS_NUM   = 286479;        // n = v·286479 / 10^9
static const int64_t CMD_TIMEOUT_US    = 30000;
static const int64_t REPLY_DELAY_US    = 600;

// Pedal fault: track B open for 95 000 <= t_ms < 95 300.
static const int64_t PEDAL_FAULT_FROM_MS = 95000;
static const int64_t PEDAL_FAULT_TO_MS   = 95300;

// Blackout: MCU R sends no feedback scheduled in 72 000 000 <= t < 72 120 000 µs.
static const int64_t BLACKOUT_FROM_US = 72000000;
static const int64_t BLACKOUT_TO_US   = 72120000;

// Frame schedules: period 10 ms, phases 2 ms (MCU L), 2.5 ms (MCU R), 7 ms (IMU).
static const int64_t FRAME_PERIOD_US = 10000;
static const int64_t PHASE_FB_L_US   = 2000;
static const int64_t PHASE_FB_R_US   = 2500;
static const int64_t PHASE_IMU_US    = 7000;

// ---- State ----

struct mcu_state {
    int      node;              // SIM_NODE_MCU_L or SIM_NODE_MCU_R
    uint32_t cmd_id;            // 0x101 or 0x102
    uint32_t fb_id;             // 0x181 or 0x182
    uint32_t info_id;           // 0x381 or 0x382
    int64_t  phase_us;          // feedback phase
    uint32_t firmware;          // MCU_INFO constants (§2.16.3)
    uint32_t serial_no;

    bool     have_cmd;          // a valid command frame has arrived
    int64_t  cmd;               // its TorqueCmd, 0.1 N·m
    bool     enable;            // its Enable bit
    int64_t  cmd_t;             // its end time

    int64_t  t_act;             // shaft torque, mN·m
    int64_t  n;                 // motor speed of the last tick, rev/min
    bool     derate;            // status of the last tick
    bool     cmd_timeout;

    int64_t  j_next;            // index j of the next scheduled feedback frame
    uint32_t counter;           // feedback counter (mod 16 on the wire)
};

// A frame queued for a later time: a late feedback frame or a reply to a remote frame.
struct pending_frame {
    int64_t   t;
    int       node;
    bool      feedback;         // true: a late feedback frame; false: a reply
    sim_frame f;
};

static bool model_bench = false;

static int64_t q_trace = 0;         // pedal travel of the last tick, per mille
static int64_t delta_true = 0;      // steering of the last tick, mrad
static uint16_t adc_a = 0, adc_b = 0, adc_s = 0;

static mcu_state mcu[2];

static int64_t veh_v = 0;           // µm/s, >= 0
static int64_t veh_r = 0;           // µrad/s

static int64_t  imu_j_next = 0;
static uint32_t imu_counter = 0;

static std::vector<pending_frame> pending;

// ---- Initialisation ----

static void mcu_init(mcu_state *m, int node, uint32_t cmd_id, uint32_t fb_id, uint32_t info_id,
                     int64_t phase_us, uint32_t firmware, uint32_t serial_no) {
    *m = mcu_state{};
    m->node = node;
    m->cmd_id = cmd_id;
    m->fb_id = fb_id;
    m->info_id = info_id;
    m->phase_us = phase_us;
    m->firmware = firmware;
    m->serial_no = serial_no;
}

void sim_model_init(bool bench) {
    model_bench = bench;
    gen_adc = SEED_ADC;
    gen_mot = SEED_MOT;
    gen_imu = SEED_IMU;
    gen_bus = SEED_BUS;
    q_trace = 0;
    delta_true = 0;
    adc_a = adc_b = adc_s = 0;
    // Firmware and serial numbers of the two motor controllers (§2.16.3).
    mcu_init(&mcu[0], SIM_NODE_MCU_L, W8_ID_TQ_CMD_L, W8_ID_MCU_FB_L, W8_ID_MCU_INFO_L,
             PHASE_FB_L_US, 0x0213u, 0x4C0A1001u);
    mcu_init(&mcu[1], SIM_NODE_MCU_R, W8_ID_TQ_CMD_R, W8_ID_MCU_FB_R, W8_ID_MCU_INFO_R,
             PHASE_FB_R_US, 0x0212u, 0x4C0A1002u);
    veh_v = 0;
    veh_r = 0;
    imu_j_next = 0;
    imu_counter = 0;
    pending.clear();
}

// ---- The tick ----

// One motor controller over one tick: the torque target, its limits and the first-order lag.
static void mcu_tick(mcu_state *m, int64_t t) {
    m->cmd_timeout = !m->have_cmd || (t - m->cmd_t) > CMD_TIMEOUT_US;
    int64_t target = (m->enable && !m->cmd_timeout) ? m->cmd : 0;
    // Torque limit from the peak torque, the power limit and the speed fade.
    int64_t an = iabs(m->n);
    int64_t t_lim = imin(MOTOR_PEAK, tdiv(MOTOR_POWER_K, imax(an, 1)));
    if (an >= MOTOR_FADE_END) {
        t_lim = 0;
    } else if (an >= MOTOR_FADE_START) {
        t_lim = tdiv(t_lim * (MOTOR_FADE_END - an), MOTOR_FADE_END - MOTOR_FADE_START);
    }
    int64_t t_t = clamp(target, -t_lim, t_lim);
    m->derate = (t_t != target);
    // 8 ms first-order lag of the shaft torque (0.1 N·m -> mN·m is ×100).
    m->t_act += tdiv(100 * t_t - m->t_act, MOTOR_LAG_TICKS);
}

// The vehicle over one tick (explicit Euler over 1 ms), then the wheel and motor speeds.
static void vehicle_tick(void) {
    int64_t v = veh_v;
    int64_t r = veh_r;
    int64_t f_l = 30 * mcu[0].t_act;            // mN: T [mN·m] / 0.3 m · gear 9
    int64_t f_r = 30 * mcu[1].t_act;
    int64_t f_d = 0;                            // rolling and aerodynamic drag
    if (v != 0) {
        f_d = ROLL_RES_MN + tdiv(36 * v * v, 100000000000);
    }
    int64_t v_new = imax(0, v + tdiv(f_l + f_r - f_d, VEH_MASS_KG));
    int64_t du = 1000 * delta_true;             // µrad
    int64_t r_new = 0;
    if (v != 0) {
        int64_t r_ss = tdiv(v * du, WHEELBASE_UM + tdiv(v * v, UNDERSTEER_DIV));
        r_new = r + tdiv(r_ss - r, YAW_RELAX_TICKS) + tdiv(f_r - f_l, YAW_MOMENT_DIV);
    }
    veh_v = v_new;
    veh_r = r_new;
    // Wheel speeds at the half track of 0.75 m, then motor speeds through the gear.
    int64_t v_l = veh_v - tdiv(3 * veh_r, 4);
    int64_t v_r = veh_v + tdiv(3 * veh_r, 4);
    mcu[0].n = tdiv(v_l * RPM_PER_UMS_NUM, 1000000000);
    mcu[1].n = tdiv(v_r * RPM_PER_UMS_NUM, 1000000000);
}

void sim_model_tick(int64_t t) {
    int64_t t_ms = t / 1000;
    // Traces.
    q_trace = trace_value(TRACE_Q, sizeof TRACE_Q / sizeof TRACE_Q[0], t_ms);
    delta_true = trace_value(TRACE_DELTA, sizeof TRACE_DELTA / sizeof TRACE_DELTA[0], t_ms);
    // ADC latch: three S_ADC draws in the order A, B, S.
    int64_t a = clamp(410 + tdiv(q_trace * 3276, 1000) + uniform(&gen_adc, 2), 0, 4095);
    int64_t b = clamp(205 + tdiv(q_trace * 1638, 1000) + uniform(&gen_adc, 2), 0, 4095);
    int64_t s = clamp(2048 + tdiv(delta_true * 2048, 350) + uniform(&gen_adc, 1), 0, 4095);
    if (t_ms >= PEDAL_FAULT_FROM_MS && t_ms < PEDAL_FAULT_TO_MS) {
        b = 0;      // track B open, after its draw
    }
    adc_a = (uint16_t)a;
    adc_b = (uint16_t)b;
    adc_s = (uint16_t)s;
    // Motors, then the vehicle and the wheel speeds.
    mcu_tick(&mcu[0], t);
    mcu_tick(&mcu[1], t);
    vehicle_tick();
}

uint16_t sim_model_adc(uint8_t pin) {
    switch (pin) {
    case 36: return adc_a;
    case 39: return adc_b;
    case 34: return adc_s;
    default: return 0;
    }
}

// ---- Frames ----

static int64_t fb_time(const mcu_state *m) {
    return FRAME_PERIOD_US * m->j_next + m->phase_us;
}

static int64_t imu_time(void) {
    return FRAME_PERIOD_US * imu_j_next + PHASE_IMU_US;
}

// The IMU frame of time t: YawRate in mrad/s with S_IMU noise, the 8-bit counter.
static void imu_frame(void) {
    sim_frame f = {};
    f.id = W8_ID_IMU_YAW;
    f.dlc = W8_DLC_IMU_YAW;
    int64_t yaw = clamp(tdiv(veh_r, 1000) + uniform(&gen_imu, 3), -32768, 32767);
    w8_put_le16(&f.data[0], (int32_t)yaw);
    f.data[2] = (uint8_t)(imu_counter & 0xFFu);
    imu_counter++;
    sim_bus_enqueue(SIM_NODE_IMU, &f);
}

// A motor controller's scheduled feedback frame at time t: the frame is built from the last
// tick with its S_MOT draw, then one S_BUS draw (two for a late frame) decides its fate.
static void feedback_frame(mcu_state *m, int64_t t) {
    sim_frame f = {};
    f.id = m->fb_id;
    f.dlc = W8_DLC_MCU_FB;
    int64_t tq = clamp(tdiv(m->t_act, 100) + uniform(&gen_mot, 2), -32768, 32767);
    int64_t p = m->t_act * m->n;
    int64_t cur = clamp(tdiv(p, p >= 0 ? K_MOTORING : K_GENERATING), -1024, 1023);
    uint32_t status = W8_FB_READY | (m->derate ? W8_FB_DERATE : 0u) |
                      (m->cmd_timeout ? W8_FB_CMD_TIMEOUT : 0u);
    w8_put_be16(&f.data[0], (int32_t)tq);
    w8_put_be16(&f.data[2], (int32_t)m->n);
    w8_put_cur_status(&f.data[4], (int32_t)cur, status);
    f.data[6] = (uint8_t)(m->counter & 0x0Fu);
    f.data[7] = w8_checksum(f.id, f.data, f.dlc);
    m->counter++;           // a dropped frame still uses up its counter value
    m->j_next++;

    // The fault draw: u = next mod 1000, and for a late frame w = next.
    uint32_t u = gen_next(&gen_bus) % 1000u;
    uint32_t w = 0;
    if (u == 2 || u == 3) {
        w = gen_next(&gen_bus);
    }
    bool blackout = (m->node == SIM_NODE_MCU_R && t >= BLACKOUT_FROM_US && t < BLACKOUT_TO_US);
    if (blackout || u == 0 || u == 1) {
        return;     // not sent (blackout or dropped); the draws are discarded
    }
    if (u == 2 || u == 3) {
        // Late: 3.000 ... 7.000 ms after its scheduled time, with its scheduled values.
        pending.push_back(pending_frame{t + 3000 + (int64_t)(w % 4001u), m->node, true, f});
        return;
    }
    if (u == 4) {
        f.data[7] ^= 0x5Au;     // corrupted checksum
    }
    sim_bus_enqueue(m->node, &f);
}

// Queue the pending frames of time t of one kind (and, for feedback, one node), in the
// order they were scheduled.
static void flush_pending(int64_t t, bool feedback, int node) {
    for (size_t i = 0; i < pending.size();) {
        const pending_frame &p = pending[i];
        if (p.t == t && p.feedback == feedback && (!feedback || p.node == node)) {
            sim_bus_enqueue(p.node, &p.f);
            pending.erase(pending.begin() + (std::ptrdiff_t)i);
        } else {
            ++i;
        }
    }
}

void sim_model_enqueue(int64_t t) {
    if (model_bench) {
        return;     // the MCU and IMU nodes are silent on the bench
    }
    if (t == imu_time()) {
        imu_frame();
        imu_j_next++;
    }
    for (int k = 0; k < 2; ++k) {
        if (t == fb_time(&mcu[k])) {
            feedback_frame(&mcu[k], t);
        }
        flush_pending(t, true, mcu[k].node);
    }
    flush_pending(t, false, 0);
}

int64_t sim_model_next_event(int64_t from) {
    if (model_bench) {
        return INT64_MAX;
    }
    int64_t next = imu_time();
    next = imin(next, fb_time(&mcu[0]));
    next = imin(next, fb_time(&mcu[1]));
    for (const pending_frame &p : pending) {
        next = imin(next, p.t);
    }
    return imax(next, from);
}

// ---- Frames from the VCU ----

void sim_model_receive(const sim_frame *f, int64_t t) {
    for (int k = 0; k < 2; ++k) {
        mcu_state *m = &mcu[k];
        if (f->id == m->cmd_id && !f->rtr) {
            // Latch a complete command frame with a valid checksum.
            if (f->dlc == W8_DLC_TQ_CMD &&
                f->data[3] == w8_checksum(f->id, f->data, W8_DLC_TQ_CMD)) {
                m->have_cmd = true;
                m->cmd = w8_get_le16s(&f->data[0]);
                m->enable = ((f->data[2] >> 4) & 1u) != 0;
                m->cmd_t = t;
            }
        } else if (f->id == m->info_id && f->rtr) {
            // Answer the remote frame 600 µs after its end with firmware and serial number.
            sim_frame r = {};
            r.id = m->info_id;
            r.dlc = W8_DLC_MCU_INFO;
            w8_put_le16(&r.data[0], (int32_t)m->firmware);
            w8_put_le16(&r.data[2], (int32_t)(m->serial_no & 0xFFFFu));
            w8_put_le16(&r.data[4], (int32_t)(m->serial_no >> 16));
            pending.push_back(pending_frame{t + REPLY_DELAY_US, m->node, false, r});
        }
    }
}
