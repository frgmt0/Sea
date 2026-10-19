"""Run every NumPy cross-check and write reference/<name>.py.json.

Usage (from sea/workloads):
    uv run --no-project --with numpy python reference_py/run_all.py

The .py.json files are independent cross-checks of the MATLAB workloads. Once MATLAB has
produced reference/<name>.json (run_all.m), those MATLAB files are the authority; use
reference_py/compare.py to check that the two agree within the documented tolerances.
"""

import importlib
import os
import platform
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

NAMES = ["w1_shaft_design", "w2_truss_fem", "w3_quarter_car", "w4_heat_plate",
         "w5_tolerance_mc"]


def main():
    times = []
    for name in NAMES:
        mod = importlib.import_module(name)
        t0 = time.perf_counter()
        mod.main()
        times.append(time.perf_counter() - t0)
        print()
    print("NumPy %s, Python %s, %s" % (np.__version__, platform.python_version(),
                                        platform.machine()))
    for name, t in zip(NAMES, times):
        print("  %-18s %8.2f s" % (name, t))
    print("These timings are for the cross-check scripts only; they are not the MATLAB "
          "baseline.")


if __name__ == "__main__":
    main()
