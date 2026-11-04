// w8_can_msgs.h - the CAN message set of the W8 electric car (Sea DESIGN.md §2.16.3).
//
// One table in code, shared by the VCU sketch (w8_ev_can.ino) and the host model of the
// motor controllers and the yaw-rate sensor: the frame identifiers, the data length codes,
// the VCU state numbers, the MCU status bits, and the few inline helpers that pack and
// unpack the signals. Nothing else in this file has behaviour.
//
// Conventions of the message set:
//   * classic CAN, 11-bit identifiers; byte k is the k-th data byte on the wire;
//   * Intel signals put their least significant byte at the lower byte number, Motorola
//     signals their most significant byte there;
//   * signed signals are two's complement of their stated width; reserved bits are 0.
//
// Portability: fixed-width integer types only, and no floating-point type or value, so the
// same text compiles for the ESP32 and for the Mac, whose basic integer types differ in
// width, and computes the same numbers on both.

#ifndef W8_CAN_MSGS_H
#define W8_CAN_MSGS_H

#include <stdint.h>

// ---- Frame identifiers (11-bit) ----
static const uint32_t W8_ID_IMU_YAW    = 0x0A0;  // yaw-rate sensor, 10 ms
static const uint32_t W8_ID_TQ_CMD_L   = 0x101;  // VCU -> left motor torque command, 10 ms
static const uint32_t W8_ID_TQ_CMD_R   = 0x102;  // VCU -> right motor torque command, 10 ms
static const uint32_t W8_ID_VCU_DRIVER = 0x120;  // VCU driver inputs and torque request, 10 ms
static const uint32_t W8_ID_VCU_YAW    = 0x121;  // VCU yaw control values and flags, 10 ms
static const uint32_t W8_ID_MCU_FB_L   = 0x181;  // left motor controller feedback, 10 ms
static const uint32_t W8_ID_MCU_FB_R   = 0x182;  // right motor controller feedback, 10 ms
static const uint32_t W8_ID_MCU_INFO_L = 0x381;  // left MCU firmware/serial (remote request + reply)
static const uint32_t W8_ID_MCU_INFO_R = 0x382;  // right MCU firmware/serial (remote request + reply)
static const uint32_t W8_ID_VCU_HB     = 0x710;  // VCU heartbeat, 100 ms

// ---- Data length codes ----
static const uint8_t W8_DLC_IMU_YAW    = 3;
static const uint8_t W8_DLC_TQ_CMD     = 4;      // both 0x101 and 0x102
static const uint8_t W8_DLC_VCU_DRIVER = 8;
static const uint8_t W8_DLC_VCU_YAW    = 8;
static const uint8_t W8_DLC_MCU_FB     = 8;      // both 0x181 and 0x182
static const uint8_t W8_DLC_MCU_INFO   = 6;      // the data reply, and the DLC code of its remote frame
static const uint8_t W8_DLC_VCU_HB     = 2;

// ---- VCU states (the State signals of 0x101/0x102, 0x120 and 0x710) ----
static const uint8_t W8_ST_INIT       = 0;
static const uint8_t W8_ST_RUN        = 1;
static const uint8_t W8_ST_FAULT_FB   = 2;
static const uint8_t W8_ST_FAULT_APPS = 3;

// ---- MCU feedback Status bits (byte 5 bits 0-3 of 0x181/0x182) ----
static const uint32_t W8_FB_READY       = 1;
static const uint32_t W8_FB_DERATE      = 2;
static const uint32_t W8_FB_CMD_TIMEOUT = 4;

// ---- Arithmetic helpers ----

// a / b truncated toward zero (C++ integer division), for b > 0.
static inline int32_t w8_tdiv32(int32_t a, int32_t b) {
    return a / b;
}

// a / b truncated toward zero, 64-bit, for b > 0.
static inline int64_t w8_tdiv64(int64_t a, int64_t b) {
    return a / b;
}

// x limited to lo ... hi (lo <= hi). Deliberately not a template, so int32_t and int
// arguments mix freely on both targets.
static inline int32_t w8_clamp32(int32_t x, int32_t lo, int32_t hi) {
    if (x < lo) {
        return lo;
    }
    if (x > hi) {
        return hi;
    }
    return x;
}

// x limited to lo ... hi, 64-bit.
static inline int64_t w8_clamp64(int64_t x, int64_t lo, int64_t hi) {
    if (x < lo) {
        return lo;
    }
    if (x > hi) {
        return hi;
    }
    return x;
}

// ---- Checksum ----

// The checksum byte of a frame with identifier id and dlc data bytes: the sum of the two
// identifier bytes and data[0 ... dlc-2], its low byte inverted. The checksum itself goes in
// data[dlc-1]; a frame is valid when that byte equals this value.
static inline uint8_t w8_checksum(uint32_t id, const uint8_t *data, uint8_t dlc) {
    uint32_t s = (id & 0xFFu) + (id >> 8);
    for (uint32_t i = 0; i + 1u < (uint32_t)dlc; ++i) {
        s += data[i];
    }
    return (uint8_t)((s & 0xFFu) ^ 0xFFu);
}

// ---- 16-bit fields ----

// Intel 16-bit field: the low 16 bits of v, low byte first.
static inline void w8_put_le16(uint8_t *p, int32_t v) {
    uint32_t u = (uint32_t)v;           // two's complement bit pattern
    p[0] = (uint8_t)(u & 0xFFu);
    p[1] = (uint8_t)((u >> 8) & 0xFFu);
}

// Intel 16-bit field read back sign-extended.
static inline int32_t w8_get_le16s(const uint8_t *p) {
    int32_t s = (int32_t)((uint32_t)p[0] | ((uint32_t)p[1] << 8));
    if (s >= 32768) {
        s -= 65536;                     // top bit set: a negative value
    }
    return s;
}

// Motorola 16-bit field: the low 16 bits of v, high byte first.
static inline void w8_put_be16(uint8_t *p, int32_t v) {
    uint32_t u = (uint32_t)v;
    p[0] = (uint8_t)((u >> 8) & 0xFFu);
    p[1] = (uint8_t)(u & 0xFFu);
}

// Motorola 16-bit field read back sign-extended.
static inline int32_t w8_get_be16s(const uint8_t *p) {
    int32_t s = (int32_t)(((uint32_t)p[0] << 8) | (uint32_t)p[1]);
    if (s >= 32768) {
        s -= 65536;
    }
    return s;
}

// Unsigned Intel 16-bit word (the 0x120 driver word, the MCU firmware number).
static inline uint32_t w8_get_u16le(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8);
}

// ---- MCU feedback: DcCurrent (12-bit signed) and Status (4 bits) in bytes 4 and 5 ----

// p points at byte 4: p[0] = current bits 11-4, p[1] = current bits 3-0 in the high nibble,
// the status bits in the low nibble.
static inline void w8_put_cur_status(uint8_t *p, int32_t cur, uint32_t status) {
    uint32_t u = (uint32_t)cur & 0xFFFu; // 12-bit two's complement pattern
    p[0] = (uint8_t)(u >> 4);
    p[1] = (uint8_t)(((u & 0x0Fu) << 4) | (status & 0x0Fu));
}

// The current read back, sign-extended from 12 bits.
static inline int32_t w8_get_cur(const uint8_t *p) {
    int32_t s = (int32_t)(((uint32_t)p[0] << 4) | ((uint32_t)p[1] >> 4));
    if (s >= 2048) {
        s -= 4096;
    }
    return s;
}

// The four status bits.
static inline uint32_t w8_get_status(const uint8_t *p) {
    return (uint32_t)p[1] & 0x0Fu;
}

#endif  // W8_CAN_MSGS_H
