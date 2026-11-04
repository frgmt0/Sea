// sim.h - the shared declarations of the W8 host simulator w8sim (Sea DESIGN.md §2.16.5).
//
// This is the interface between the mock (the Arduino and TWAI API the sketch calls, the
// bus and the event loop) and the model (the motor controllers, the yaw-rate sensor, the
// vehicle, the traces and the faults). The mock owns the clock and the bus; the model is
// driven by the event loop and puts its frames on the bus through sim_bus_enqueue.
//
// Time is an integer count of microseconds since boot (t = 0 when setup() runs). Every
// quantity of the simulator is an integer: there is no floating-point type anywhere
// (DESIGN.md §2.16.7, the determinism rule).

#ifndef W8SIM_SIM_H
#define W8SIM_SIM_H

#include <stdint.h>

// ---- Nodes on the bus (each has its own FIFO transmit queue) ----
enum {
    SIM_NODE_VCU   = 0,     // the sketch, through the TWAI driver mock
    SIM_NODE_IMU   = 1,     // the yaw-rate sensor (model)
    SIM_NODE_MCU_L = 2,     // the left rear motor controller (model)
    SIM_NODE_MCU_R = 3,     // the right rear motor controller (model)
    SIM_NODES      = 4
};

// One classic CAN frame with an 11-bit identifier, as the bus carries it.
struct sim_frame {
    uint32_t id;            // 11-bit identifier
    uint8_t  rtr;           // 1 for a remote frame
    uint8_t  dlc;           // data length code (on the wire also for a remote frame)
    uint8_t  self;          // self-reception request (bench mode only)
    uint8_t  data[8];       // data bytes; unused for a remote frame
};

// ---- The run (set by main.cpp from the command line) ----
struct sim_config {
    bool    bench;          // --bench: mode strap open, MCU and IMU silent
    int64_t end_us;         // the run's end, --seconds N times 1 000 000
};
extern sim_config sim_cfg;

// The current simulated time in µs. Only the event loop (main.cpp) moves it.
extern int64_t sim_t;

// Stop w8sim with exit status 2 after printing "w8sim: <what>" on standard error (a usage
// error, an unsupported call of the sketch, or a file that cannot be written).
[[noreturn]] void sim_fatal(const char *what);

// ---- Clock (main.cpp): delay() and delayMicroseconds() advance the time by dt µs,
//      processing every model and bus event on the way without calling loop() ----
void sim_advance(int64_t dt_us);

// ---- Serial output (mock_core.cpp) ----
void sim_serial_open(const char *path);
void sim_serial_close(void);            // flushes; stops with status 2 on a write error

// ---- The bus (mock_twai.cpp) ----
void sim_bus_open_log(const char *path);    // path may be null: no bus log
void sim_bus_close_log(void);
// Queue a frame of a model node at the current time (FIFO per node).
void sim_bus_enqueue(int node, const sim_frame *f);
// Step (3) of the event loop at time t: deliver and log the frame that ends at t, then let
// the queue heads arbitrate if the bus is idle.
void sim_bus_end_and_arbitrate(int64_t t);
// Step (5) at time t: arbitrate if the bus is idle (a frame loop() queued starts at t).
void sim_bus_arbitrate(int64_t t);
// The next time >= from at which the bus has something to do (a frame end, or the idle
// instant after an intermission while a frame waits), or INT64_MAX.
int64_t sim_bus_next_event(int64_t from);
// The number of frames lost at the VCU's full receive queue.
uint32_t sim_bus_rx_lost(void);

// ---- The sketch (sketch.cpp, which includes the unmodified w8_ev_can.ino) ----
void setup(void);
void loop(void);

#endif  // W8SIM_SIM_H
