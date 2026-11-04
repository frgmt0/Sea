// main.cpp - the command line and the event loop of w8sim, the W8 host simulator (Sea
// DESIGN.md §2.16.5, L-nj).
//
//   w8sim [--bench] [--seconds N] [--log FILE] --serial FILE
//
// The car run is --seconds 120 --log FILE --serial FILE; the bench run --bench --seconds 5
// --serial FILE. --log is required without --bench. Exit status 0, or 2 with a message on
// standard error.
//
// The event loop. Events happen at integer µs: the model's 1 ms ticks, the model's frame
// times, the bus's frame ends and idle instants, and the sketch's loop times t = 50·i.
// setup() runs first, at t = 0. At each event time t, in this order:
//   (1) the model's tick, if t is a tick time (a multiple of 1 000, t >= 1 000);
//   (2) the model's frame enqueues of time t;
//   (3) the bus: the frame ending at t is delivered and logged; if the bus is idle the queue
//       heads arbitrate;
//   (4) loop(), if t is a loop time and t < the run's end;
//   (5) the bus arbitrates again if still idle (a frame loop() queued starts at t).
// Events at exactly the run's end are processed, but loop() does not run then.

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sim.h"
#include "model.h"

sim_config sim_cfg = {false, 0};
int64_t sim_t = 0;

static const int64_t TICK_US = 1000;        // the model's tick period
static const int64_t LOOP_US = 50;          // the sketch's loop period

// The last event time fully processed (-1: none yet). delay() moves it too.
static int64_t processed_upto = -1;

void sim_fatal(const char *what) {
    fprintf(stderr, "w8sim: %s\n", what);
    exit(2);
}

// The smallest multiple of step that is >= x (x >= 0).
static int64_t ceil_to(int64_t x, int64_t step) {
    return ((x + step - 1) / step) * step;
}

// The next event time >= from (loop times counted only when with_loop).
static int64_t next_event_time(int64_t from, bool with_loop) {
    int64_t next = ceil_to(from < TICK_US ? TICK_US : from, TICK_US);
    int64_t m = sim_model_next_event(from);
    if (m < next) {
        next = m;
    }
    int64_t b = sim_bus_next_event(from);
    if (b < next) {
        next = b;
    }
    if (with_loop) {
        int64_t l = ceil_to(from, LOOP_US);
        if (l < sim_cfg.end_us && l < next) {
            next = l;
        }
    }
    return next;
}

// Steps (1)-(3) of event time t.
static void process_model_and_bus(int64_t t) {
    sim_t = t;
    if (t >= TICK_US && t % TICK_US == 0) {
        sim_model_tick(t);
    }
    sim_model_enqueue(t);
    sim_bus_end_and_arbitrate(t);
}

void sim_advance(int64_t dt_us) {
    int64_t target = sim_t + dt_us;
    // Step (5) of the current time first: a frame queued just before the delay starts now.
    sim_bus_arbitrate(sim_t);
    int64_t from = sim_t + 1;
    for (;;) {
        int64_t t = next_event_time(from, false);
        if (t > target || t > sim_cfg.end_us) {
            break;
        }
        process_model_and_bus(t);
        sim_bus_arbitrate(t);
        from = t + 1;
    }
    sim_t = target;
    if (target > processed_upto) {
        processed_upto = target;
    }
}

static void usage(const char *why) {
    fprintf(stderr, "w8sim: %s\n", why);
    fprintf(stderr, "usage: w8sim [--bench] [--seconds N] [--log FILE] --serial FILE\n");
    exit(2);
}

// A positive decimal integer of at most 6 digits (up to 999 999 s of simulated time).
static int64_t parse_seconds(const char *s) {
    int64_t v = 0;
    size_t n = strlen(s);
    if (n == 0 || n > 6) {
        usage("--seconds needs a positive integer");
    }
    for (size_t i = 0; i < n; ++i) {
        if (s[i] < '0' || s[i] > '9') {
            usage("--seconds needs a positive integer");
        }
        v = v * 10 + (s[i] - '0');
    }
    if (v == 0) {
        usage("--seconds needs a positive integer");
    }
    return v;
}

int main(int argc, char **argv) {
    bool bench = false;
    int64_t seconds = 120;
    const char *log_path = nullptr;
    const char *serial_path = nullptr;
    for (int i = 1; i < argc; ++i) {
        const char *a = argv[i];
        if (strcmp(a, "--bench") == 0) {
            bench = true;
        } else if (strcmp(a, "--seconds") == 0 && i + 1 < argc) {
            seconds = parse_seconds(argv[++i]);
        } else if (strcmp(a, "--log") == 0 && i + 1 < argc) {
            log_path = argv[++i];
        } else if (strcmp(a, "--serial") == 0 && i + 1 < argc) {
            serial_path = argv[++i];
        } else {
            usage("unknown or incomplete argument");
        }
    }
    if (serial_path == nullptr) {
        usage("--serial FILE is required");
    }
    if (!bench && log_path == nullptr) {
        usage("--log FILE is required without --bench");
    }

    sim_cfg.bench = bench;
    sim_cfg.end_us = seconds * 1000000;
    sim_serial_open(serial_path);
    sim_bus_open_log(log_path);
    sim_model_init(bench);

    // setup() at t = 0, before any event.
    sim_t = 0;
    setup();

    // The event loop up to and including the run's end.
    for (;;) {
        int64_t t = next_event_time(processed_upto + 1, true);
        if (t > sim_cfg.end_us) {
            break;
        }
        process_model_and_bus(t);
        if (t % LOOP_US == 0 && t < sim_cfg.end_us) {
            loop();         // may advance sim_t through delay()
        }
        sim_bus_arbitrate(sim_t);
        if (sim_t > processed_upto) {
            processed_upto = sim_t;
        }
    }

    sim_bus_close_log();
    sim_serial_close();
    if (sim_bus_rx_lost() != 0) {
        fprintf(stderr, "w8sim: %" PRIu32 " frames lost at the VCU's full receive queue\n",
                sim_bus_rx_lost());
    }
    return 0;
}
