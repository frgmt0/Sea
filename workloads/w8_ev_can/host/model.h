// model.h - the deterministic motor, sensor and vehicle model of w8sim (Sea DESIGN.md §2.16.6).
//
// The event loop (main.cpp) calls the model at its own times: the 1 ms tick in step (1),
// the frame enqueues in step (2); the bus (mock_twai.cpp) hands it every VCU frame that
// ends on the bus (car mode only); the ADC mock (mock_core.cpp) reads its latched values.

#ifndef W8SIM_MODEL_H
#define W8SIM_MODEL_H

#include <stdint.h>
#include "sim.h"

// Reset the model for a car run (bench = false) or a bench run (MCU and IMU silent: only
// the traces, the ADC latch and S_ADC run, and the motors and vehicle stand still).
void sim_model_init(bool bench);

// Step (1): the model's tick at t = 1 000·j (j >= 1): traces, ADC latch, MCU L, MCU R,
// vehicle, wheel speeds.
void sim_model_tick(int64_t t);

// Step (2): queue the model's frames of time t, in the order IMU, MCU L's feedback,
// MCU R's feedback, then replies to remote frames.
void sim_model_enqueue(int64_t t);

// The earliest time >= from at which the model queues a frame, or INT64_MAX.
int64_t sim_model_next_event(int64_t from);

// A VCU frame ended on the bus at time t: the motor controllers latch their commands and
// answer remote frames.
void sim_model_receive(const sim_frame *f, int64_t t);

// The raw 12-bit ADC value the last tick latched for pin 36, 39 or 34 (0 for other pins).
uint16_t sim_model_adc(uint8_t pin);

#endif  // W8SIM_MODEL_H
