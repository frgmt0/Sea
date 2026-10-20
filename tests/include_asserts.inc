// tests/include_asserts.inc -- assertions on Sea's contract include files,
// shared by tests/include_check.s (Apple as, arm64 Mach-O) and
// tests/include_check_x86_64.s (GNU as, x86_64 ELF). Arch-neutral: only
// directives and expressions, `//` comments only at the start of a line
// (Baysick DESIGN.md 3.4). Every condition is fully parenthesised: GNU as
// would read a bare `NAME == x` macro argument as the keyword argument
// `NAME=`.
// The including file must have included, in this order, Baysick's
// include/limits.inc and include/runtime.inc, then limits.inc, errors.inc
// and rt.inc (DESIGN.md 2.6, 6.2).

.macro SEA_ASSERT cond, msg
.if !(\cond)
.error "\msg"
.endif
.endm

// ---- limits.inc (DESIGN.md 2.6.1) ----------------------------------------
SEA_ASSERT (SEA_LIM_EXTENT == ((1 << 31) - 1)),             "extents are 0 .. 2^31 - 1"
SEA_ASSERT (SEA_LIM_STR_BYTES == ((1 << 31) - 1)),          "str lengths are 0 .. 2^31 - 1"
SEA_ASSERT (SEA_LIM_IDENT_BYTES < SEA_LIM_LINE_BYTES),      "an identifier fits a line"
SEA_ASSERT ((SEA_LIM_FIXED_MATMUL_E*SEA_LIM_FIXED_MATMUL_E) <= SEA_LIM_FIXED_ELEMS), "a class-E fixed matmul operand is a fixed-size array"
SEA_ASSERT ((SEA_SUM_LANES & (SEA_SUM_LANES - 1)) == 0),    "summation lanes are a power of two"
SEA_ASSERT (SEA_LIM_DEC_FIELD == 999999999),                "decimal fields have at most 9 digits (Baysick VAL)"
// Baysick limits the passes live within (DESIGN.md 2.7, 3.1, 3.9)
SEA_ASSERT (SEA_LIM_RECORD_BYTES == LIM_INPUT_LINE),        "a record line is one Baysick LINPUT"
SEA_ASSERT (SEA_LIM_PASSES_LINE <= LIM_INPUT_LINE),         "a passes.txt line is one Baysick LINPUT"
SEA_ASSERT ((3*SEA_LIM_LINE_BYTES + 16) < SEA_LIM_RECORD_BYTES), "an escaped literal of a longest source line fits a record"
// the pass tables of DESIGN.md 2.7: N(99999,8) Y(49999,9) T(19999,7) C(19999,4) S$(199999)
SEA_ASSERT (((SEA_LIM_NODES + 1)*9) <= LIM_ARRAY_ELEMS),    "table N fits a Baysick array"
SEA_ASSERT (((SEA_LIM_SYMBOLS + 1)*10) <= LIM_ARRAY_ELEMS), "table Y fits a Baysick array"
SEA_ASSERT (((SEA_LIM_TYPES + 1)*8) <= LIM_ARRAY_ELEMS),    "table T fits a Baysick array"
SEA_ASSERT (((SEA_LIM_CONSTS + 1)*5) <= LIM_ARRAY_ELEMS),   "table C fits a Baysick array"
SEA_ASSERT ((SEA_LIM_STRINGS + 1) <= LIM_ARRAY_ELEMS),      "table S$ fits a Baysick array"
// the LIR pass tables of DESIGN.md 2.7: L$(199999) D(49999,3) I(199999,4) O(799999)
// R(99999,7) K(19999,4) C(199999,4) X(49999,1); K holds blocks in rows 1..9999, slots above
SEA_ASSERT ((SEA_LIM_LIR_INSTRS + 1) <= LIM_ARRAY_ELEMS),   "table L$ fits a Baysick array"
SEA_ASSERT (((SEA_LIM_LIR_LABELS + 1)*4) <= LIM_ARRAY_ELEMS), "table D fits a Baysick array"
SEA_ASSERT (((SEA_LIM_LIR_INSTRS + 1)*5) <= LIM_ARRAY_ELEMS), "table I fits a Baysick array"
SEA_ASSERT ((SEA_LIM_LIR_OPERANDS + 1) <= LIM_ARRAY_ELEMS), "table O fits a Baysick array"
SEA_ASSERT (((SEA_LIM_LIR_REGS + 1)*8) <= LIM_ARRAY_ELEMS), "table R fits a Baysick array"
SEA_ASSERT (((SEA_LIM_LIR_BLOCKS + SEA_LIM_LIR_SLOTS + 2)*5) <= LIM_ARRAY_ELEMS), "table K fits a Baysick array"
SEA_ASSERT ((SEA_LIM_LIR_BLOCKS + 1) == 10000),             "slots start at row 10000 of table K"
SEA_ASSERT (((SEA_LIM_LIR_IMMS + 1)*5) <= LIM_ARRAY_ELEMS), "table C (immediates) fits a Baysick array"
SEA_ASSERT (((SEA_LIM_LIR_SITES + 1)*2) <= LIM_ARRAY_ELEMS), "table X fits a Baysick array"
SEA_ASSERT (SEA_LIM_LIR_REGS <= 99999),                     "a register token has at most 6 bytes (DESIGN.md 3.1)"
SEA_ASSERT (SEA_LIM_RESULTS <= SEA_LIM_PARAMS),             "result lists are bounded like parameter lists (DESIGN.md 3.1)"
// runtime sizes (DESIGN.md 4.1)
SEA_ASSERT ((SEA_SMALL_MAX_BYTES & (SEA_SMALL_MAX_BYTES - 1)) == 0), "small-block bound is a power of two"
SEA_ASSERT ((SEA_CHUNK_BYTES & (SEA_CHUNK_BYTES - 1)) == 0), "chunk size is a power of two"
SEA_ASSERT (SEA_SMALL_MAX_BYTES < SEA_CHUNK_BYTES),         "a chunk holds small blocks"

// ---- errors.inc (DESIGN.md 2.6.2) ----------------------------------------
// Walk the error list: codes unique, in their phase's range, run-time codes
// dense from 1 in list order; phase one of R D C1 C2 CX P; at "-" exactly
// for R and P; args "-" or letters.
.set sea_chk_nr, 1
.macro SEA_CHK_E code, name, ph, at, args, text
.equiv sea_chk_code_\code, 1
.set sea_chk_ph, 0
.ifc \ph,R
.set sea_chk_ph, 1
SEA_ASSERT (\code == sea_chk_nr),                           "run-time codes are dense from 1 in list order: \name"
.set sea_chk_nr, sea_chk_nr + 1
.endif
.ifc \ph,D
.set sea_chk_ph, 2
SEA_ASSERT ((\code >= 100) && (\code < 200)),               "D code in 100..199: \name"
.endif
.ifc \ph,C1
.set sea_chk_ph, 2
SEA_ASSERT ((\code >= 100) && (\code < 200)),               "C1 code in 100..199: \name"
.endif
.ifc \ph,C2
.set sea_chk_ph, 2
SEA_ASSERT ((\code >= 200) && (\code < 400)),               "C2 code in 200..399: \name"
.endif
.ifc \ph,CX
.set sea_chk_ph, 2
SEA_ASSERT ((\code >= 400) && (\code < 500)),               "CX code in 400..499: \name"
.endif
.ifc \ph,P
.set sea_chk_ph, 1
SEA_ASSERT ((\code >= 500) && (\code < 600)),               "P code in 500..599: \name"
.endif
SEA_ASSERT (sea_chk_ph != 0),                               "unknown phase: \name"
.ifc \at,-
SEA_ASSERT (sea_chk_ph == 1),                               "a compile-time message names its position: \name"
.else
SEA_ASSERT (sea_chk_ph == 2),                               "R and P messages have no position: \name"
.endif
.endm
SEA_ERROR_LIST SEA_CHK_E
SEA_ASSERT (sea_chk_nr == SEA_E_RT_END),                    "SEA_E_RT_END is one past the last run-time code"
SEA_ASSERT (SEA_E_USER == (SEA_E_RT_END - 1)),              "the user error is the last run-time code"

// Walk the errno list: ids dense from 0; record 0 is the fallback.
.set sea_chk_ne, 0
.macro SEA_CHK_N id, name, darwin, linux, text
SEA_ASSERT (\id == sea_chk_ne),                             "errno ids are dense from 0 in list order: \name"
.set sea_chk_ne, sea_chk_ne + 1
.endm
SEA_ERRNO_LIST SEA_CHK_N
SEA_ASSERT (sea_chk_ne == SEA_ERRNO_COUNT),                 "SEA_ERRNO_COUNT is the number of errno records"
SEA_ASSERT (SEA_ERRNO_UNKNOWN == 0),                        "errno record 0 is the fallback"
SEA_ASSERT ((SEA_ERRTAB_ARGS + 8) == SEA_ERRTAB_SIZE),      "SEA_ERRTAB layout"
SEA_ASSERT ((SEA_ERRNO_TEXT + 8) == SEA_ERRNO_SIZE),        "SEA_ERRNO layout"
SEA_ASSERT (SEA_EXIT_COMPILE != SEA_EXIT_OK),               "driver statuses differ"
SEA_ASSERT (SEA_EXIT_PASS_COMPILE != SEA_EXIT_PASS_INTERNAL), "pass statuses differ"

// ---- rt.inc (DESIGN.md 4.8) ----------------------------------------------
SEA_ASSERT (SEA_ARR_RC == SEA_OBJ_RC),                      "arrays start with the object header"
SEA_ASSERT (SEA_ARR_TAG == SEA_OBJ_TAG),                    "array tag in the object header"
SEA_ASSERT (SEA_STR_RC == SEA_OBJ_RC),                      "strings start with the object header"
SEA_ASSERT (SEA_STR_TAG == SEA_OBJ_TAG),                    "string tag in the object header"
SEA_ASSERT ((SEA_ARR_EK == (SEA_OBJ_TAG + 1)) && (SEA_ARR_RANK == (SEA_ARR_EK + 1))), "array byte fields follow the tag"
SEA_ASSERT (SEA_ARR_ROWS == SEA_OBJ_HDR),                   "array fields follow the object header"
SEA_ASSERT ((SEA_ARR_COLS == (SEA_ARR_ROWS + 8)) && (SEA_ARR_CAP == (SEA_ARR_COLS + 8))), "array extent fields"
SEA_ASSERT ((SEA_ARR_DATA == (SEA_ARR_CAP + 8)) && (SEA_ARR_ESIZE == (SEA_ARR_DATA + 8))), "array data fields"
SEA_ASSERT ((SEA_ARR_SLAY + 8) == SEA_ARR_SIZE),            "SEA_ARR layout"
SEA_ASSERT ((SEA_ARR_SIZE % 16) == 0),                      "array headers keep 16-byte alignment"
SEA_ASSERT ((SEA_DATA_ALIGN & (SEA_DATA_ALIGN - 1)) == 0),  "data alignment is a power of two"
SEA_ASSERT (SEA_STR_LEN == SEA_OBJ_HDR),                    "string length follows the object header"
SEA_ASSERT ((SEA_STR_LEN + 8) == SEA_STR_BYTES),            "SEA_STR layout"
SEA_ASSERT ((SEA_SL_NREF == (SEA_SL_SIZE + 8)) && (SEA_SL_REFS == (SEA_SL_NREF + 8))), "SEA_SL layout"
SEA_ASSERT ((SEA_FP_CLS == (SEA_FP_FLAGS + 1)) && (SEA_FP_FLAGS == (SEA_FP_CONV + 1)) && (SEA_FP_CONV == (SEA_FP_KIND + 1))), "format piece byte fields"
SEA_ASSERT ((SEA_FP_PREC == (SEA_FP_WIDTH + 4)) && (SEA_FP_TEXT == 16) && (SEA_FP_TLEN == (SEA_FP_TEXT + 8))), "format piece fields"
SEA_ASSERT ((SEA_FP_TLEN + 8) == SEA_FP_SIZE),              "SEA_FP layout"
SEA_ASSERT ((SEA_FMT_NCONV + 8) == SEA_FMT_PIECES),         "SEA_FMT layout"
SEA_ASSERT ((SEA_FF_LEFT | SEA_FF_PLUS | SEA_FF_SPACE | SEA_FF_ZERO | SEA_FF_ALT) == 0x1F), "five distinct format flags"
SEA_ASSERT ((SEA_CLS_F == (SEA_CLS_I + 1)) && (SEA_CLS_P == (SEA_CLS_F + 1))), "register classes"
SEA_ASSERT ((SEA_SITE_LINE + 8) == SEA_SITE_SIZE),          "SEA_SITE layout"
SEA_ASSERT (SEA_SLOT_SIZE == SEA_ESIZE_PTR),                "a slot holds a pointer"
SEA_ASSERT ((SEA_ESIZE_F64 == SEA_SLOT_SIZE) && (SEA_ESIZE_I64 == SEA_SLOT_SIZE)), "a slot holds a number"
SEA_ASSERT ((SEA_TAG_CHOL - SEA_TAG_ARRAY) == 5),           "object tags are dense"
SEA_ASSERT ((SEA_EK_STRUCT - SEA_EK_F64) == 4),             "element kinds are dense"
SEA_ASSERT ((SEA_VAR_AVX2 - SEA_VAR_NEON) == 2),            "variant ids are dense"
SEA_ASSERT (SEA_RC_STATIC == 0),                            "a static object has count 0"
