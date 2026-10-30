"""Run the NumPy cross-checks and write reference/<name>.py.json.

Usage (from sea/workloads):
    uv run --no-project --with numpy python reference_py/run_all.py            # every workload
    uv run --no-project --with numpy python reference_py/run_all.py w7_drivetrain   # only these

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
         "w5_tolerance_mc", "w6_topopt", "w7_drivetrain"]


def main(argv):
    names = argv or NAMES
    for name in names:
        if name not in NAMES:
            print("unknown workload %s (known: %s)" % (name, " ".join(NAMES)), file=sys.stderr)
            return 2
    times = []
    for name in names:
        mod = importlib.import_module(name)
        t0 = time.perf_counter()
        mod.main()
        times.append(time.perf_counter() - t0)
        print()
    print("NumPy %s, Python %s, %s" % (np.__version__, platform.python_version(),
                                        platform.machine()))
    for name, t in zip(names, times):
        print("  %-18s %8.2f s" % (name, t))
    print("These timings are for the cross-check scripts only; they are not the MATLAB "
          "baseline.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
