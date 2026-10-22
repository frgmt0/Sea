# Sea -- build and checks on the Mac (arm64-macos), docs/DESIGN.md 2.6.3, 2.10, 6.
#
#   make                  = make all
#   make all              build/ = the installation directory (DESIGN.md 2.10): runtime, tools,
#                         every pass that is written, and the install step. A part that is not
#                         written yet is reported ("make: ... not written yet"), not hidden,
#                         and does not stop the parts that exist.
#   make runtime          build/libsea.a from runtime/arm64_macos/*.s
#   make tools            build/tools/gendata, build/tools/seaval from tools/*.bas
#   make passes           build/<pass> for each of seaparse seaname seacheck seaexpand sealoop sealower seaopt
#                         seagen_a64: build/gen/<pass>.bas (passes/<pass>/*.bas, then the modules
#                         and DATA blocks of passes/<pass>/build.list, then 99999 END; DESIGN.md
#                         2.6.3), compiled with $(BAYSICK)/build/baysick
#   make install          build/sea (the driver), build/std.sea, build/errors.inc,
#                         build/limits.inc, build/libbaysickrt.a (copied from Baysick's build)
#   make test             all, then every test group below that has its script; fails if any fails
#   make test-programs    tests/run.sh      programs/ and errors/ (built passes, end to end)
#   make test-rt          tests/rt/run_rt.sh  runtime tests (assembly programs against libsea.a)
#   make test-stage       tests/stage.sh    each pass on the golden output of the previous one
#   make test-accept      tests/accept4.sh  phase-4 acceptance programs against compare.py --keys (needs uv)
#   make test-protocol    tests/protocol.sh pass protocol: missing #end, driver #end check
#   make test-driver      tests/driver_check.sh  the driver without passes
#   make test-lib         tests/lib_check.sh    the shared pass modules
#   make test-arith       tests/arith_check.sh  the exact-arithmetic modules
#   make test-math        tests/math/math_check.c (xcrun cc) against build/libsea.a and
#                         tests/math/*.vec: log exp sin cos pow hypot, bit for bit (4.10.6)
#   make math-tables      uv run tools/math_tables.py --check (timeout 120): the committed
#                         include/math_tables.inc equals its definitions; developer tool,
#                         not part of make test
#   make check-data       tests/check_data.sh   the DATA generator on the contract files
#   make lines            line count of each built pass vs Baysick's LIM_LINES
#   make check-limits     lines, FOR statements, string-constant bytes, 255-byte lines
#   make check-includes   first make check-contracts, then assemble the contract
#                         include files (include/*.inc) with Apple as: layout
#                         assertions, code ranges, table sizes, and no name clash
#                         with Baysick's include/limits.inc and include/runtime.inc
#   make check-contracts  the drift check (tests/check_contracts.sh, sh + awk):
#                         every SEA_* name and value, error and errno record of
#                         include/*.inc and every record format of
#                         include/passes.txt equals the tables of docs/DESIGN.md
#                         (2.6.1, 2.6.2, 3, 4.8), and vice versa
#   make cross-pack       pack the x86_64-linux test bundle into build/x86_64-linux-bundle
#   make cross            pack, run on the Linux host (HOST=... or SEA_CROSS_HOST, default desktop), report
#   make cross-includes   the same check with GNU as on the Linux host
#                         (tests/cross_includes.sh; HOST=... to override)
#   make clean            remove build/
#
# BAYSICK is the Baysick checkout (default: the parent repository, Sea being its submodule
# at sea/); its build/baysick and build/libbaysickrt.a must exist for the passes (run make
# there first). The include check works in a temporary directory and leaves no files behind.
#
# Per-pass build list, passes/<pass>/build.list (one file per pass; '#' starts a comment):
#   lib <module>...    shared modules of passes/lib/: io diag tables limb f64emu fltlit
#   data <block>...    generated DATA blocks: errors errno exits consts entries records mtab
# The parts are concatenated in the canonical order of DESIGN.md 2.6.3 whatever the order
# written; an unknown name is a build error.
#
# tools/gendata is run in include/ (it opens limits.inc errors.inc rt.inc passes.txt math_tables.inc by fixed
# names) with the block names, canonical order, one per line, on standard input; the DATA lines,
# numbered from 89000, are its standard output.

AS      := as
BAYSICK ?= ..
# The ssh host: HOST=... on the command line, else $(SEA_CROSS_HOST), else desktop (a stray
# exported HOST of csh-family shells is deliberately ignored).
ifeq ($(origin HOST),command line)
CROSS_HOST := $(HOST)
else
CROSS_HOST := $(or $(SEA_CROSS_HOST),desktop)
endif
BUILD   := build

BSK      := $(BAYSICK)/build/baysick
BSKRT    := $(BAYSICK)/build/libbaysickrt.a
PASSES   := seaparse seaname seacheck seaexpand sealoop sealower seaopt seagen_a64 seagen_x64
LIBS_CANON := io diag tables limb f64emu fltlit
DATA_CANON := errors errno exits consts entries records mtab
RT_EXPECTED := rt_main rt_out rt_err rt_fmt rt_clock rt_math rt_mem rt_arr rt_str rt_args

INCLUDES := include/limits.inc include/errors.inc include/rt.inc include/math_tables.inc
ASFLAGS_BASE := -arch arm64 -mmacosx-version-min=11.0 -I include -I tests
RT_ASFLAGS := -arch arm64 -mmacosx-version-min=11.0 -I include -I $(BAYSICK)/include
RT_SRCS := $(wildcard runtime/arm64_macos/*.s)
RT_OBJS := $(patsubst runtime/arm64_macos/%.s,$(BUILD)/obj/runtime/%.o,$(RT_SRCS))
BAYSICK_INC := $(wildcard $(BAYSICK)/include/runtime.inc $(BAYSICK)/include/limits.inc)

.PHONY: all runtime tools passes install check-baysick FORCE \
        test test-programs test-accept test-rt test-stage test-protocol test-driver test-lib test-arith test-math math-tables \
        check-data lines check-limits clean \
        check-includes check-contracts cross-includes cross cross-pack
.DEFAULT_GOAL := all

all: install runtime tools passes

# ---- install directory ----------------------------------------------------------------
install: $(BUILD)/sea $(BUILD)/std.sea $(BUILD)/errors.inc $(BUILD)/limits.inc
	@if [ -f "$(BSKRT)" ]; then \
	  if ! cmp -s "$(BSKRT)" $(BUILD)/libbaysickrt.a; then cp "$(BSKRT)" $(BUILD)/libbaysickrt.a; fi; \
	else \
	  echo "make: $(BSKRT) not found: build Baysick first (make -C $(BAYSICK)); build/libbaysickrt.a not installed" >&2; \
	fi

$(BUILD)/sea: driver/sea
	@mkdir -p $(BUILD)
	cp driver/sea $@ && chmod +x $@
$(BUILD)/std.sea: std/std.sea
	@mkdir -p $(BUILD)
	cp std/std.sea $@
$(BUILD)/errors.inc: include/errors.inc
	@mkdir -p $(BUILD)
	cp include/errors.inc $@
$(BUILD)/limits.inc: include/limits.inc
	@mkdir -p $(BUILD)
	cp include/limits.inc $@

check-baysick:
	@if [ ! -x "$(BSK)" ] || [ ! -f "$(BSKRT)" ]; then \
	  echo "make: Baysick's compiler $(BSK) or runtime $(BSKRT) not found: run make in $(BAYSICK) first (BAYSICK=$(BAYSICK))" >&2; exit 1; \
	fi

# ---- runtime ----------------------------------------------------------------------------
runtime:
	@missing=""; for m in $(RT_EXPECTED); do \
	  [ -f runtime/arm64_macos/$$m.s ] || missing="$$missing $$m.s"; done; \
	if [ -n "$$missing" ]; then \
	  echo "make: runtime/arm64_macos: not written yet:$$missing" >&2; \
	fi
	@if [ -z "$(RT_SRCS)" ]; then \
	  echo "make: runtime/arm64_macos has no assembly sources: $(BUILD)/libsea.a not built" >&2; \
	else \
	  $(MAKE) --no-print-directory $(BUILD)/libsea.a; \
	fi

$(BUILD)/libsea.a: $(RT_OBJS)
	rm -f $@
	ar rcs $@ $(RT_OBJS)

$(BUILD)/obj/runtime/%.o: runtime/arm64_macos/%.s $(INCLUDES) $(BAYSICK_INC)
	@mkdir -p $(dir $@)
	$(AS) $(RT_ASFLAGS) -o $@ $<

# ---- tools ------------------------------------------------------------------------------
# gendata is standalone; seaval is built like a pass (its file + modules + DATA + 99999 END,
# tools/seaval.build.list, same format as passes/<pass>/build.list).
tools:
	@if [ -f tools/gendata.bas ]; then $(MAKE) --no-print-directory $(BUILD)/tools/gendata || exit 1; \
	else echo "make: tools/gendata.bas not written yet" >&2; fi
	@if [ -f tools/seaval.bas ]; then $(MAKE) --no-print-directory $(BUILD)/tools/seaval || exit 1; \
	else echo "make: tools/seaval.bas not written yet" >&2; fi

$(BUILD)/tools/gendata: tools/gendata.bas | check-baysick
	@mkdir -p $(BUILD)/tools
	$(BSK) $< -o $@

$(BUILD)/tools/seaval: $(BUILD)/gen/seaval.bas | check-baysick
	@mkdir -p $(BUILD)/tools
	$(BSK) $(BUILD)/gen/seaval.bas -o $@

$(BUILD)/gen/seaval.bas: FORCE | $(BUILD)/tools/gendata
	@sh -c "$$GEN_PASS" gen_pass seaval tools/seaval.bas tools/seaval.build.list

# ---- passes -----------------------------------------------------------------------------
# build/gen/<pass>.bas is regenerated on every build (FORCE) and replaced only if its content
# changed, so build/<pass> is recompiled exactly when the generated program differs.
passes:
	@if [ -f tools/gendata.bas ]; then $(MAKE) --no-print-directory $(BUILD)/tools/gendata || exit 1; fi; \
	for p in $(PASSES); do \
	  if ls passes/$$p/*.bas > /dev/null 2>&1; then \
	    $(MAKE) --no-print-directory $(BUILD)/$$p || exit 1; \
	  else \
	    echo "make: pass $$p not written yet (no passes/$$p/*.bas)" >&2; \
	  fi; \
	done

define PASS_RULES
$$(BUILD)/$(1): $$(BUILD)/gen/$(1).bas | check-baysick
	$$(BSK) $$(BUILD)/gen/$(1).bas -o $$@

$$(BUILD)/gen/$(1).bas: FORCE
	@sh -c "$$$$GEN_PASS" gen_pass $(1) "passes/$(1)/*.bas" passes/$(1)/build.list
endef
$(foreach p,$(PASSES),$(eval $(call PASS_RULES,$(p))))

# The generator: $1 = program name, $2 = its own source files, $3 = its build list. Parts in the order of DESIGN.md 2.6.3.
define GEN_SCRIPT
p=$$1; own=$$2; list=$$3; out=$(BUILD)/gen/$$p.bas
[ -f $$list ] || { echo "make: $$list missing" >&2; exit 1; }
libs=$$(awk '$$1 == "lib" { for (i = 2; i <= NF; i++) print $$i }' $$list)
data=$$(awk '$$1 == "data" { for (i = 2; i <= NF; i++) print $$i }' $$list)
for w in $$libs; do case " $(LIBS_CANON) " in *" $$w "*) ;; *) echo "make: $$list: unknown module '$$w'" >&2; exit 1 ;; esac; done
for w in $$data; do case " $(DATA_CANON) " in *" $$w "*) ;; *) echo "make: $$list: unknown DATA block '$$w'" >&2; exit 1 ;; esac; done
mkdir -p $(BUILD)/gen; t=$$(mktemp -d "$${TMPDIR:-/tmp}/sea-gen.XXXXXX") || exit 1
trap 'rm -rf "$$t"' EXIT
: > $$t/prog.bas
for f in $$own; do awk 1 "$$f" >> $$t/prog.bas; done
for m in $(LIBS_CANON); do
  for w in $$libs; do
    if [ "$$w" = "$$m" ]; then
      [ -f passes/lib/$$m.bas ] || { echo "make: $$list: passes/lib/$$m.bas not written yet" >&2; exit 1; }
      awk 1 passes/lib/$$m.bas >> $$t/prog.bas
    fi
  done
done
blocks=
for b in $(DATA_CANON); do for w in $$data; do [ "$$w" = "$$b" ] && blocks="$$blocks $$b"; done; done
if [ -n "$$blocks" ]; then
  [ -x $(BUILD)/tools/gendata ] || { echo "make: $(BUILD)/tools/gendata not built (tools/gendata.bas not written yet?); needed for $$p" >&2; exit 1; }
  gd=$$(cd $(BUILD)/tools && pwd)/gendata
  printf '%s\n' $$blocks | (cd include && "$$gd") >> $$t/prog.bas || { echo "make: gendata failed for $$p" >&2; exit 1; }
fi
echo "99999 END" >> $$t/prog.bas
if cmp -s $$t/prog.bas $$out; then :; else cp $$t/prog.bas $$out; fi
endef
export GEN_PASS = $(GEN_SCRIPT)

FORCE:

# ---- tests ------------------------------------------------------------------------------
# run_group SCRIPT [ARGS]: a missing script is a failure with a clear message.
define RUN_SCRIPT
	@if [ ! -f $(1) ]; then echo "make: $(1) not written yet" >&2; exit 1; fi
	BUILD=$(BUILD) BAYSICK=$(BAYSICK) sh $(1)
endef

test-programs: all
	$(call RUN_SCRIPT,tests/run.sh)
test-rt: runtime
	$(call RUN_SCRIPT,tests/rt/run_rt.sh)
test-stage: all
	$(call RUN_SCRIPT,tests/stage.sh)
test-accept: all
	$(call RUN_SCRIPT,tests/accept4.sh)
test-protocol: all
	$(call RUN_SCRIPT,tests/protocol.sh)
test-driver: install
	$(call RUN_SCRIPT,tests/driver_check.sh)
test-lib: tools
	$(call RUN_SCRIPT,tests/lib_check.sh)
test-arith: tools
	$(call RUN_SCRIPT,tests/arith_check.sh)
test-math: runtime
	@if [ ! -f tests/math/math_check.c ]; then echo "make: tests/math/math_check.c not written yet" >&2; exit 1; fi
	@mkdir -p $(BUILD)/obj
	env -u SDKROOT xcrun cc -O1 -ffp-contract=off -Wall -o $(BUILD)/obj/math_check tests/math/math_check.c $(BUILD)/libsea.a -lm
	$(BUILD)/obj/math_check tests/math

# Developer check (not part of make test): the committed tables equal their definitions.
math-tables:
	timeout 120 uv run --with mpmath python tools/math_tables.py --check

check-data: tools
	$(call RUN_SCRIPT,tests/check_data.sh)

# Every group runs even if an earlier one fails; the exit status is 1 if any failed.
test: all check-contracts
	@st=0; \
	for g in test-driver check-data test-lib test-arith test-math test-rt test-stage test-protocol test-programs test-accept; do \
	  echo "== make $$g"; \
	  $(MAKE) --no-print-directory $$g || { echo "== $$g FAILED"; st=1; }; \
	done; \
	if [ $$st -eq 0 ]; then echo "== all test groups passed"; else echo "== some test groups failed"; fi; \
	exit $$st

lines:
	@BUILD=$(BUILD) BAYSICK=$(BAYSICK) sh tools/passlines.sh lines
check-limits:
	@BUILD=$(BUILD) BAYSICK=$(BAYSICK) sh tools/passlines.sh limits

clean:
	rm -rf $(BUILD)

# ---- contract checks (DESIGN.md 2.6, 6.2) -------------------------------------------------
# The include files are shared with the x86_64-linux runtime (GNU as), where
# `//` only starts a comment at the beginning of a line: a trailing comment
# must be written /* ... */ (Baysick DESIGN.md 3.4). The grep enforces it.
check-contracts: $(INCLUDES) include/passes.txt docs/DESIGN.md tests/check_contracts.sh
	@sh tests/check_contracts.sh

check-includes: check-contracts $(INCLUDES) tests/include_check.s tests/include_asserts.inc
	@if [ ! -f "$(BAYSICK)/include/limits.inc" ] || [ ! -f "$(BAYSICK)/include/runtime.inc" ]; then \
	  echo "make: Baysick's include/limits.inc and include/runtime.inc not found under BAYSICK=$(BAYSICK)" >&2; exit 1; \
	fi
	@if grep -nE '^[[:space:]]*[^[:space:]/].*//' $(INCLUDES) tests/include_asserts.inc; then \
	  echo "make: trailing // comment in a shared include file (use /* ... */)" >&2; exit 1; \
	fi
	@t=$$(mktemp -d "$${TMPDIR:-/tmp}/sea-incl.XXXXXX") || exit 1; \
	b=$$(cd "$(BAYSICK)" && pwd); \
	printf '// generated by make check-includes\n.include "%s/include/limits.inc"\n.include "%s/include/runtime.inc"\n' "$$b" "$$b" > "$$t/bsk_contract.inc"; \
	echo "$(AS) $(ASFLAGS_BASE) -I $$t -o $$t/include_check.o tests/include_check.s"; \
	$(AS) $(ASFLAGS_BASE) -I "$$t" -o "$$t/include_check.o" tests/include_check.s; st=$$?; \
	rm -rf "$$t"; \
	if [ $$st -ne 0 ]; then exit $$st; fi
	@t=$$(mktemp -d "$${TMPDIR:-/tmp}/sea-mtab.XXXXXX") || exit 1; \
	printf '.include "math_tables.inc"\n    .section __TEXT,__const\n    SEA_EMIT_MATH_TABLES\n' > "$$t/mt.s"; \
	echo "$(AS) $(ASFLAGS_BASE) -o $$t/mt.o $$t/mt.s (math_tables.inc)"; \
	$(AS) $(ASFLAGS_BASE) -o "$$t/mt.o" "$$t/mt.s"; st=$$?; \
	rm -rf "$$t"; \
	if [ $$st -ne 0 ]; then exit $$st; fi
	@echo "include files assemble, layout assertions hold, no clash with Baysick's include/limits.inc and include/runtime.inc"

cross-includes:
	sh tests/cross_includes.sh -H $(CROSS_HOST) -B "$(BAYSICK)"

# ---- x86_64-linux cross testing (DESIGN.md 6.6.1) -----------------------------------------
# cross-pack: the bundle build/x86_64-linux-bundle (removed first); cross: pack, ship by ssh to
# HOST (default desktop), run there, report. Both need seagen_x64 and the x86_64 runtime.
cross-pack: all
	rm -rf $(BUILD)/x86_64-linux-bundle
	SEA=$(BUILD)/sea BAYSICK=$(BAYSICK) sh tests/cross_pack.sh -o $(BUILD)/x86_64-linux-bundle

cross: all
	SEA=$(BUILD)/sea BAYSICK=$(BAYSICK) sh tests/cross.sh -H $(CROSS_HOST)
