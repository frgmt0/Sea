// driver/twai.h - the w8sim mock of the ESP-IDF legacy TWAI driver as the ESP32 Arduino core
// 3.3.7 ships it (Sea DESIGN.md §2.16.5, L-nh).
//
// The types, macros and the four functions the W8 sketch uses, with the field order and
// types of esp32-libs/3.3.7's driver/twai.h, hal/twai_types.h and hal/twai_types_deprecated.h
// (the plain-ESP32 values). The real header's other functions (status, alerts, recovery, the
// _v2 forms) are deliberately not declared. The definitions are in mock_twai.cpp.

#ifndef W8SIM_DRIVER_TWAI_H
#define W8SIM_DRIVER_TWAI_H

#include <stdint.h>
#include <stdbool.h>

// ---- esp_err.h ----
typedef int esp_err_t;
#define ESP_OK                 0
#define ESP_FAIL               -1
#define ESP_ERR_INVALID_ARG    0x102
#define ESP_ERR_INVALID_STATE  0x103
#define ESP_ERR_TIMEOUT        0x107

// ---- FreeRTOS tick count (portmacro.h, 32-bit ticks) ----
typedef uint32_t TickType_t;

// ---- GPIO numbers: only the two TWAI pins. The underlying type is fixed to int so that
//      TWAI_IO_UNUSED (-1) is a valid value, as it is in the core, whose gpio_num_t has the
//      member GPIO_NUM_NC = -1. ----
typedef enum : int {
    GPIO_NUM_21 = 21,
    GPIO_NUM_22 = 22
} gpio_num_t;

#define TWAI_IO_UNUSED ((gpio_num_t) -1)

// ---- hal/twai_types_deprecated.h ----
#define TWAI_MSG_FLAG_NONE          0x00    // standard frame format (11-bit identifier)
#define TWAI_MSG_FLAG_EXTD          0x01    // extended frame format (29-bit identifier)
#define TWAI_MSG_FLAG_RTR           0x02    // remote frame
#define TWAI_MSG_FLAG_SS            0x04    // single-shot transmission
#define TWAI_MSG_FLAG_SELF          0x08    // self-reception request
#define TWAI_MSG_FLAG_DLC_NON_COMP  0x10    // data length code above 8

typedef enum {
    TWAI_MODE_NORMAL,       // send, receive and acknowledge
    TWAI_MODE_NO_ACK,       // transmissions need no acknowledgement (self test)
    TWAI_MODE_LISTEN_ONLY,  // receive only
} twai_mode_t;

typedef struct {
    union {
        struct {
            uint32_t extd: 1;           // extended frame format (29-bit identifier)
            uint32_t rtr: 1;            // remote frame
            uint32_t ss: 1;             // single-shot transmission (unused when received)
            uint32_t self: 1;           // self-reception request (unused when received)
            uint32_t dlc_non_comp: 1;   // data length code above 8
            uint32_t reserved: 27;
        };
        uint32_t flags;                 // the same bits as TWAI_MSG_FLAG_* values
    };
    uint32_t identifier;                // 11- or 29-bit identifier
    uint8_t data_length_code;
    uint8_t data[8];
} twai_message_t;

typedef struct {
    uint32_t acceptance_code;
    uint32_t acceptance_mask;
    bool single_filter;
} twai_filter_config_t;

// ---- hal/twai_types.h: the clock source (on the ESP32 soc_periph_twai_clk_src_t, whose
//      default is the APB clock, SOC_MOD_CLK_APB = 4) and the bit timing ----
typedef enum {
    TWAI_CLK_SRC_DEFAULT = 4
} twai_clock_source_t;

typedef struct {
    twai_clock_source_t clk_src;
    uint32_t quanta_resolution_hz;
    uint32_t brp;
    uint8_t  prop_seg;
    uint8_t  tseg_1;
    uint8_t  tseg_2;
    uint8_t  sjw;
    uint8_t  ssp_offset;
    bool triple_sampling;
} twai_timing_config_t;

// ---- driver/twai.h ----
typedef struct {
    int controller_id;
    twai_mode_t mode;
    gpio_num_t tx_io;
    gpio_num_t rx_io;
    gpio_num_t clkout_io;
    gpio_num_t bus_off_io;
    uint32_t tx_queue_len;
    uint32_t rx_queue_len;
    uint32_t alerts_enabled;
    uint32_t clkout_divider;
    int intr_flags;
    struct {
        uint32_t sleep_allow_pd;
    } general_flags;
} twai_general_config_t;

// The core's initializers. In TWAI_GENERAL_CONFIG_DEFAULT the core writes the alert mask as
// TWAI_ALERT_NONE (0) and the interrupt flags as ESP_INTR_FLAG_LEVEL1 (1 << 1); the mock
// writes their values, since it does not declare those names.
#define TWAI_GENERAL_CONFIG_DEFAULT_V2(controller_num, tx_io_num, rx_io_num, op_mode) \
    {.controller_id = controller_num, .mode = op_mode, .tx_io = tx_io_num, .rx_io = rx_io_num, \
     .clkout_io = TWAI_IO_UNUSED, .bus_off_io = TWAI_IO_UNUSED, \
     .tx_queue_len = 5, .rx_queue_len = 5, \
     .alerts_enabled = 0x00000000, .clkout_divider = 0, \
     .intr_flags = (1 << 1), .general_flags = {0}}
#define TWAI_GENERAL_CONFIG_DEFAULT(tx_io_num, rx_io_num, op_mode) \
    TWAI_GENERAL_CONFIG_DEFAULT_V2(0, tx_io_num, rx_io_num, op_mode)

#define TWAI_TIMING_CONFIG_500KBITS() \
    {.clk_src = TWAI_CLK_SRC_DEFAULT, .quanta_resolution_hz = 8000000, .brp = 0, .prop_seg = 0, \
     .tseg_1 = 11, .tseg_2 = 4, .sjw = 2, .ssp_offset = 0, .triple_sampling = false}

#define TWAI_FILTER_CONFIG_ACCEPT_ALL() \
    {.acceptance_code = 0, .acceptance_mask = 0xFFFFFFFF, .single_filter = true}

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t twai_driver_install(const twai_general_config_t *g_config,
                              const twai_timing_config_t *t_config,
                              const twai_filter_config_t *f_config);
esp_err_t twai_start(void);
esp_err_t twai_transmit(const twai_message_t *message, TickType_t ticks_to_wait);
esp_err_t twai_receive(twai_message_t *message, TickType_t ticks_to_wait);

#ifdef __cplusplus
}
#endif

#endif  // W8SIM_DRIVER_TWAI_H
