// mock_core.cpp - the Arduino core part of the w8sim mock (Sea DESIGN.md §2.16.5): the clock,
// GPIO, the ADC and Serial, as declared by host/include/Arduino.h.

#include "Arduino.h"
#include "sim.h"
#include "model.h"

// ---- Clock ----

unsigned long micros() {
    // The time modulo 2^32, as the ESP32's 32-bit counter wraps.
    return (unsigned long)((uint64_t)sim_t & 0xFFFFFFFFu);
}

unsigned long millis() {
    return (unsigned long)((uint64_t)(sim_t / 1000) & 0xFFFFFFFFu);
}

void delay(uint32_t ms) {
    sim_advance((int64_t)ms * 1000);
}

void delayMicroseconds(uint32_t us) {
    sim_advance((int64_t)us);
}

// ---- GPIO ----

static uint8_t pin_mode[256];   // recorded only; the simulated pins ignore it

void pinMode(uint8_t pin, uint8_t mode) {
    pin_mode[pin] = mode;
}

int digitalRead(uint8_t pin) {
    // The mode strap: grounded in the car, open (pulled up) on the bench.
    if (pin == 25) {
        return sim_cfg.bench ? HIGH : LOW;
    }
    return LOW;
}

// ---- ADC ----

uint16_t analogRead(uint8_t pin) {
    return sim_model_adc(pin);
}

void analogReadResolution(uint8_t bits) {
    if (bits != 12) {
        sim_fatal("unsupported call: analogReadResolution with a resolution other than 12 bits");
    }
}

// ---- Serial ----

HardwareSerial Serial;

static FILE *serial_file = nullptr;

void sim_serial_open(const char *path) {
    serial_file = fopen(path, "wb");
    if (serial_file == nullptr) {
        sim_fatal("cannot write the Serial output file");
    }
}

void sim_serial_close(void) {
    if (serial_file == nullptr) {
        return;
    }
    bool bad = ferror(serial_file) != 0;
    if (fclose(serial_file) != 0) {
        bad = true;
    }
    serial_file = nullptr;
    if (bad) {
        sim_fatal("cannot write the Serial output file");
    }
}

void HardwareSerial::begin(unsigned long baud) {
    (void)baud;     // the simulated port has no line rate
}

size_t HardwareSerial::print(const char *s) {
    size_t n = strlen(s);
    if (serial_file != nullptr && n > 0 && fwrite(s, 1, n, serial_file) != n) {
        sim_fatal("cannot write the Serial output file");
    }
    return n;
}
