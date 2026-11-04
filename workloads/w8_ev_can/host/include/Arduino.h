// Arduino.h - the w8sim mock of the ESP32 Arduino core 3.3.7 (Sea DESIGN.md §2.16.5).
//
// It declares exactly what the W8 sketch may use, with the core's signatures and values;
// anything else the sketch used would fail to compile on the host, which is the intended
// check. The definitions are in mock_core.cpp: the clock is the simulator's time, the ADC
// pins read the model, and Serial writes to the Serial output file.

#ifndef W8SIM_ARDUINO_H
#define W8SIM_ARDUINO_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

// Pin levels and modes (the values of the core's esp32-hal-gpio.h).
#define LOW          0x0
#define HIGH         0x1
#define INPUT        0x01
#define INPUT_PULLUP 0x05

#ifdef __cplusplus
extern "C" {
#endif

// The simulated time t in µs since boot modulo 2^32, and floor(t / 1000) modulo 2^32.
// Reading the clock does not advance it.
unsigned long micros();
unsigned long millis();

// Advance the simulated time, processing every model and bus event on the way (loop() is
// not called meanwhile).
void delay(uint32_t);
void delayMicroseconds(uint32_t us);

// pinMode is recorded and has no effect; digitalRead(25) is LOW in the car and HIGH with
// w8sim --bench; every other pin reads LOW.
void pinMode(uint8_t pin, uint8_t mode);
int digitalRead(uint8_t pin);

// Pins 36, 39 and 34 read the values the model latched at its last 1 ms tick, other pins 0.
// Only a resolution of 12 bits is accepted.
uint16_t analogRead(uint8_t pin);
void analogReadResolution(uint8_t bits);

#ifdef __cplusplus
}
#endif

// The serial port: the bytes printed are appended to the Serial output file as they are.
// println is deliberately not declared (the sketch ends its lines with its own LF).
class HardwareSerial {
public:
    void begin(unsigned long baud);
    size_t print(const char *s);
};

extern HardwareSerial Serial;

#endif  // W8SIM_ARDUINO_H
