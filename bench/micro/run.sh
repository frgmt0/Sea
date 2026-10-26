#!/bin/sh
# bench/micro/run.sh -- measure built micro-benchmark executables (docs/DESIGN.md 5.9). POSIX sh.
# Run by bench/micro.sh on the Mac and, from the unpacked bundle, on the Linux host.
#
# usage: sh run.sh TARGET DIR
#   TARGET  arm64-macos | x86_64-linux (the first TSV column)
#   DIR     holds the executables  lcg.p5 lcg.p4 lcg.c sor.p5 sor.p4 sor.c  (p5 = Sea compiled by
#           the phase-5 compiler, p4 = by the phase-4 compiler, c = the C reference)
#
# Per executable: validation first (every output checked; a failing check is an error, exit 1,
# no row), one untimed warm-up run, then repetitions (one process each; the program times its
# own kernel with a monotonic clock and prints `seconds`) until at least 5 repetitions and 1.0 s
# of total timed seconds, at most 200. Output on stdout: the TSV (header
# `target cpu bench compiler reps median_s min_s max_s unit rate`); the machine record on stderr.
# Environment: BENCH_MIN_REPS (5), BENCH_MIN_SECONDS (1.0).
# Exit status: 0 all rows written, 1 a validation failure, 2 setup error.

TARGET=${1:-}; DIR=${2:-}
[ -n "$TARGET" ] && [ -d "$DIR" ] || { echo "run.sh: usage: sh run.sh TARGET DIR" >&2; exit 2; }
MINREPS=${BENCH_MIN_REPS:-5}
MINSECS=${BENCH_MIN_SECONDS:-1.0}
MAXREPS=200
T=$(mktemp -d "${TMPDIR:-/tmp}/sea-micro.XXXXXX") || exit 2
trap 'rm -rf "$T"' EXIT
trap 'rm -rf "$T"; exit 2' HUP INT TERM PIPE

if [ "$(uname -s)" = Darwin ]; then
    CPU=$(sysctl -n machdep.cpu.brand_string)
    OSV="macOS $(sw_vers -productVersion) ($(uname -sr))"
else
    CPU=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -1)
    OSV="$(uname -sr)"
fi
LOAD=$(uptime | sed 's/.*load averages*: *//')
{
    echo "machine: $CPU"
    echo "os: $OSV"
    echo "load average at start: $LOAD"
    echo "kernel variant: none (the benchmarks call no matrix kernel; SEA_KERNELS=${SEA_KERNELS:-unset})"
} >&2

printf 'target\tcpu\tbench\tcompiler\treps\tmedian_s\tmin_s\tmax_s\tunit\trate\n'

# get KEY FILE : the value of the output line `KEY value`
get() { sed -n "s/^$1 //p" "$2" | head -1; }

# check BENCH FILE : validate one run's output; prints the reason and returns 1 on failure
check() {
    case $1 in
    lcg)
        [ "$(get lcg_final "$2")" = 2145635252 ] || { echo "lcg_final is '$(get lcg_final "$2")', want 2145635252"; return 1; }
        [ "$(get u_last "$2")" = 0.99913927400444602 ] || { echo "u_last is '$(get u_last "$2")'"; return 1; } ;;
    sor)
        awk -v it="$(get it_sor "$2")" -v tm="$(get T_max "$2")" 'BEGIN {
            if (it == "" || it < 831 || it > 833) { print "it_sor is " it ", want 832 +- 1"; exit 1 }
            d = tm - 160.76267159277148; if (d < 0) d = -d
            if (tm == "" || d > 1e-6) { print "T_max is " tm ", want 160.76267159277148 within 1e-6"; exit 1 }
            exit 0 }' || return 1
        [ "$(get npts "$2")" = 37662 ] || { echo "npts is '$(get npts "$2")', want 37662"; return 1; } ;;
    esac
    [ -n "$(get seconds "$2")" ] || { echo "no seconds line"; return 1; }
    return 0
}

STATUS=0
for bench in lcg sor; do
    for comp in p5 p4 c; do
        exe=$DIR/$bench.$comp
        [ -x "$exe" ] || { echo "run.sh: $exe missing" >&2; exit 2; }
        case $comp in p5) cname=sea-phase5 ;; p4) cname=sea-phase4 ;; c) cname=c-O2 ;; esac
        # validation + warm-up: the first run, untimed
        "$exe" >"$T/out" 2>"$T/err" </dev/null || { echo "run.sh: $bench.$comp failed: $(head -2 "$T/err")" >&2; exit 1; }
        if ! why=$(check "$bench" "$T/out"); then
            echo "run.sh: $bench $cname: validation failed: $why" >&2
            STATUS=1; continue
        fi
        : >"$T/secs"
        n=0; tot=0
        while :; do
            "$exe" >"$T/out" 2>"$T/err" </dev/null || { echo "run.sh: $bench.$comp failed: $(head -2 "$T/err")" >&2; exit 1; }
            if ! why=$(check "$bench" "$T/out"); then
                echo "run.sh: $bench $cname: validation failed in repetition $n: $why" >&2
                STATUS=1; n=-1; break
            fi
            s=$(get seconds "$T/out")
            echo "$s" >>"$T/secs"
            n=$((n + 1))
            tot=$(awk -v a="$tot" -v b="$s" 'BEGIN { printf "%.9f", a + b }')
            if [ "$n" -ge "$MAXREPS" ]; then break; fi
            if [ "$n" -ge "$MINREPS" ] && awk -v t="$tot" -v m="$MINSECS" 'BEGIN { exit !(t >= m) }'; then break; fi
        done
        [ "$n" -gt 0 ] || continue
        if [ "$bench" = lcg ]; then
            work=11000000; unit=ns/step
        else
            work=$(awk -v i="$(get it_sor "$T/out")" -v p="$(get npts "$T/out")" 'BEGIN { printf "%d", i * p }')
            unit=ns/point
        fi
        sort -n "$T/secs" | awk -v tg="$TARGET" -v cpu="$CPU" -v b="$bench" -v c="$cname" -v w="$work" -v u="$unit" '
            { v[NR] = $1 }
            END {
                med = (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2
                printf "%s\t%s\t%s\t%s\t%d\t%.6f\t%.6f\t%.6f\t%s\t%.3f\n", tg, cpu, b, c, NR, med, v[1], v[NR], u, med * 1e9 / w
            }'
    done
done
exit $STATUS
