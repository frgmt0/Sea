// =====================================================================
// sea/include/rt.inc -- the runtime ABI between compiled Sea programs
// (sea.s, written by pass 4: seagen_a64, seagen_x64) and the two runtimes
// (sea/runtime/arm64_macos/, sea/runtime/x86_64_linux/).
//
// CONTRACT FILE. Normative description: docs/DESIGN.md 4.8, which holds
// the same tables. Changes only together with that section.
//
// Shared by Apple as (arm64) and GNU as (x86_64): `//` comments only at
// the start of a line, trailing comments as /* ... */ (Baysick DESIGN.md
// 3.4). Every name is defined with .equiv, so a clash with Baysick's
// include/runtime.inc (which Sea's runtime also includes, DESIGN.md 2.6)
// is an assembly error. Guarded so it may be included more than once.
//
// Symbols (Mach-O names; the x86_64-linux ELF names drop the leading _):
//   main          runtime   process entry (DESIGN.md 4.5): stack, kernel
//                           selection, stdout buffer, then _sea_main;
//                           flushes and exits SEA_EXIT_RUN_OK when it returns;
//                           a failed final flush is _sea_err(SEA_E_CANNOT_WRITE,
//                           SEA_SITE_NONE, "<stdout>", errno)
//   _sea_main     program   the program's main function (LIR .main): no
//                           parameters, no result
//   _sea_err      runtime   noreturn: run-time error. arm64 x0 / x86_64 %rdi
//                           = code (SEA_E_*, 1 .. SEA_E_RT_END-1), x1 / %rsi
//                           = site index into _sea_sites (SEA_SITE_NONE: no
//                           location), x2 / %rdx = address
//                           of the argument slots (the code's args letters,
//                           errors.inc), unused when it has none
//   _sea_sites    program   the error-site table (SEA_SITE_* records)
//   _sea_variant  runtime   u64 SEA_VAR_* of the selected kernel variant, set
//                           before _sea_main; LIR vfeat avx2 is
//                           (_sea_variant == SEA_VAR_AVX2)
//   _sea_stack_limit runtime u64: the lowest address sp may reach; the
//                           prologue check of every checked function compares
//                           sp - frame size with it (DESIGN.md 4.6, 4.9)
// LINE SHAPES (read by the DATA generator, DESIGN.md 2.6.3; keep them exact):
// constants ".equiv SEA_<NAME>, <value>  [ /* comment */ ]", value decimal
// or 0x + upper-case hex; entry records as described at SEA_ENTRY_LIST.
// The entry points that LIR rcall records name (DESIGN.md 3.6.4) are listed
// in SEA_ENTRY_LIST below, with DESIGN.md 4.8, by the phase that implements
// each one. The elementary functions (ids 3 .. 8, DESIGN.md 4.10) read their
// tables from the generated include/math_tables.inc.
// =====================================================================
.ifndef SEA_RT_INC
.equiv SEA_RT_INC, 1

// ---- Baysick version the runtime is built against (DESIGN.md 4.3, 7.2) ----
.equiv SEA_BAYSICK_MAJOR,       0
.equiv SEA_BAYSICK_MINOR,       6
.equiv SEA_BAYSICK_PATCH,       0

// ---- Every reference-counted object (arrays, strings, handles) -------------
.equiv SEA_OBJ_RC,              0   /* u64  reference count; SEA_RC_STATIC: never counted or freed */
.equiv SEA_OBJ_TAG,             8   /* u8   SEA_TAG_* */
.equiv SEA_OBJ_HDR,             16  /* bytes of the common header; a handle's private layout follows */
.equiv SEA_RC_STATIC,           0   /* count of a static object; a dynamic object starts at 1 */
.equiv SEA_TAG_ARRAY,           1
.equiv SEA_TAG_STR,             2
.equiv SEA_TAG_FIGURE,          3
.equiv SEA_TAG_AXES,            4
.equiv SEA_TAG_LU,              5
.equiv SEA_TAG_CHOL,            6

// ---- Dynamic array header (SEA_ARR_*), 64 bytes (DESIGN.md 4.1) -------------
.equiv SEA_ARR_RC,              0   /* u64  reference count */
.equiv SEA_ARR_TAG,             8   /* u8   SEA_TAG_ARRAY */
.equiv SEA_ARR_EK,              9   /* u8   element kind SEA_EK_* */
.equiv SEA_ARR_RANK,            10  /* u8   1 vector, 2 matrix; bytes 11..15 are 0 */
.equiv SEA_ARR_ROWS,            16  /* u64  rows (the length of a vector) */
.equiv SEA_ARR_COLS,            24  /* u64  cols; 1 for a vector */
.equiv SEA_ARR_CAP,             32  /* u64  capacity in elements, >= rows * cols */
.equiv SEA_ARR_DATA,            40  /* ptr  SEA_DATA_ALIGN-aligned buffer, column-major */
.equiv SEA_ARR_ESIZE,           48  /* u64  element size in bytes */
.equiv SEA_ARR_SLAY,            56  /* ptr  SEA_SL_* descriptor for SEA_EK_STRUCT, else 0 */
.equiv SEA_ARR_SIZE,            64
.equiv SEA_DATA_ALIGN,          64  /* array buffers and dat buffers */

// Element kinds and sizes. Element (i, j) of an r x c matrix is element
// i + j*r of the buffer, at DATA + ESIZE*(i + j*r).
.equiv SEA_EK_F64,              1
.equiv SEA_EK_I64,              2
.equiv SEA_EK_BOOL,             3   /* one byte, 0 or 1 */
.equiv SEA_EK_STR,              4   /* a string object pointer */
.equiv SEA_EK_STRUCT,           5   /* a struct, inline (layout rule: DESIGN.md 4.8) */
.equiv SEA_ESIZE_F64,           8
.equiv SEA_ESIZE_I64,           8
.equiv SEA_ESIZE_BOOL,          1
.equiv SEA_ESIZE_PTR,           8   /* str, dynamic array and handle values */

// ---- Struct layout descriptor (SEA_SL_*), read-only, emitted by pass 4 ----
// One per struct type that is the element type of a dynamic array.
.equiv SEA_SL_SIZE,             0   /* u64  struct size in bytes (= SEA_ARR_ESIZE) */
.equiv SEA_SL_NREF,             8   /* u64  number of reference fields, nested ones included */
.equiv SEA_SL_REFS,             16  /* u64[SEA_SL_NREF] their byte offsets, ascending */

// ---- String object (SEA_STR_*) (DESIGN.md 4.1) ---------------------------
// Static strings (LIR str records) have count SEA_RC_STATIC and live in
// read-only data, 8-byte aligned.
.equiv SEA_STR_RC,              0   /* u64  reference count */
.equiv SEA_STR_TAG,             8   /* u8   SEA_TAG_STR; bytes 9..15 are 0 */
.equiv SEA_STR_LEN,             16  /* u64  length in bytes, 0 .. SEA_LIM_STR_BYTES */
.equiv SEA_STR_BYTES,           24  /* u8[LEN] the bytes, not NUL-terminated */

// ---- Pre-parsed format (SEA_FMT_*), read-only, from LIR fmt records -------
.equiv SEA_FMT_NPIECE,          0   /* u64  number of pieces */
.equiv SEA_FMT_NCONV,           8   /* u64  number of conversion pieces (= arguments) */
.equiv SEA_FMT_PIECES,          16  /* SEA_FP_SIZE-byte pieces in order */
.equiv SEA_FP_KIND,             0   /* u8   SEA_FPK_* */
.equiv SEA_FP_CONV,             1   /* u8   ASCII conversion letter d i f F e E g G s; 0 for text */
.equiv SEA_FP_FLAGS,            2   /* u8   SEA_FF_* bits; 0 for text */
.equiv SEA_FP_CLS,              3   /* u8   SEA_CLS_* of the argument; 0 for text */
.equiv SEA_FP_WIDTH,            4   /* i32  width, -1 absent (and for text) */
.equiv SEA_FP_PREC,             8   /* i32  precision, -1 absent (and for text); bytes 12..15 are 0 */
.equiv SEA_FP_TEXT,             16  /* ptr  text bytes (text pieces), else 0 */
.equiv SEA_FP_TLEN,             24  /* u64  number of text bytes (text pieces), else 0 */
.equiv SEA_FP_SIZE,             32
.equiv SEA_FPK_TEXT,            0
.equiv SEA_FPK_CONV,            1
.equiv SEA_FF_LEFT,             0x01 /* flag - (fl letter l) */
.equiv SEA_FF_PLUS,             0x02 /* flag + (p) */
.equiv SEA_FF_SPACE,            0x04 /* flag space (s) */
.equiv SEA_FF_ZERO,             0x08 /* flag 0 (z) */
.equiv SEA_FF_ALT,              0x10 /* flag # (a) */
.equiv SEA_CLS_I,               0   /* LIR register class i (i64, bool) */
.equiv SEA_CLS_F,               1   /* f (f64) */
.equiv SEA_CLS_P,               2   /* p (str) */

// ---- Argument slots (_sea_err and every entry taking a slot vector) -------
// 8 bytes each, in argument order: an i64 value, the bits of an f64, or an
// object pointer. A shape (args letter h) takes two slots: rows, then cols
// for a matrix or SEA_SHAPE_VEC for a vector.
.equiv SEA_SLOT_SIZE,           8
.equiv SEA_SHAPE_VEC,           -1

// ---- Error-site table (_sea_sites), read-only, emitted by pass 4 ----------
// One record per distinct LIR site F:L, numbered from 0 in order of first
// occurrence in sea.lir; the site index of _sea_err is the record number.
.equiv SEA_SITE_FILE,           0   /* ptr  static string object: the #file path F */
.equiv SEA_SITE_LINE,           8   /* u64  line L, from 1 */
.equiv SEA_SITE_SIZE,           16
.equiv SEA_SITE_NONE,           -1  /* site index of an error with no location: "error: <message>" */

// ---- Stack (DESIGN.md 4.6, 4.9) ---------------------------------------------
.equiv SEA_STACK_MARGIN,        65536 /* bytes kept above the guard page: _sea_stack_limit = guard top + this */
.equiv SEA_STACK_LEAF_MAX,      4096  /* a leaf function with a larger frame is checked too */

// ---- Runtime entry points named by LIR rcall (DESIGN.md 3.6.4, 4.8) ----------
// LINE SHAPE (read by the DATA generator, DESIGN.md 2.6): between
// ".macro SEA_ENTRY_LIST m" and the next ".endm", 4 spaces, "\m ", then
//   id, NAME, symbol, site, args, results
// id dense from 1; symbol the ELF name (Mach-O adds a leading _), which LIR
// rcall records write; site S (pass 4 passes the site index as one more,
// last, integer argument) or -; args, results: LIR register classes in
// order, or - for none. Fields separated by a comma and one space.
.macro SEA_ENTRY_LIST m
    \m 1, PRINTF, sea_printf, S, pp, -
    \m 2, NOW, sea_now, -, -, f
    \m 3, LOG, sea_log, -, f, f
    \m 4, EXP, sea_exp, -, f, f
    \m 5, SIN, sea_sin, -, f, f
    \m 6, COS, sea_cos, -, f, f
    \m 7, POW, sea_pow, -, ff, f
    \m 8, HYPOT, sea_hypot, -, ff, f
    \m 9, ARR_NEW, sea_arr_new, S, iiii, p
    \m 10, ARR_NEW_S, sea_arr_new_s, S, piii, p
    \m 11, ARR_UNIQUE, sea_arr_unique, S, p, p
    \m 12, FREE, sea_free, -, p, -
    \m 13, STR_CAT, sea_str_cat, S, pp, p
    \m 14, STR_CMP, sea_str_cmp, -, pp, i
    \m 15, STR_LOWER, sea_str_lower, S, p, p
    \m 16, STR_I64, sea_str_i64, S, i, p
    \m 17, STR_F64, sea_str_f64, S, f, p
    \m 18, ERROR, sea_error, S, pp, -
    \m 19, ARGS, sea_args, S, -, p
    \m 20, ARR_NEW_U, sea_arr_new_u, S, iiii, p
    \m 21, SORT, sea_sort, S, pi, p
    \m 22, ARGSORT, sea_argsort, S, pi, p
.endm
.equiv SEA_ENT_COUNT,           22  /* number of entry records (ids 1 .. SEA_ENT_COUNT) */
.macro SEA_ENTDEF id, name, sym, site, args, res
.equiv SEA_ENT_\name, \id
.endm
SEA_ENTRY_LIST SEA_ENTDEF

// ---- Kernel variants (DESIGN.md 4.4); names as Baysick's KV_NAME ----------
.equiv SEA_VAR_NEON,            1   /* "neon", arm64-macos */
.equiv SEA_VAR_SSE2,            2   /* "sse2", x86_64-linux */
.equiv SEA_VAR_AVX2,            3   /* "avx2", x86_64-linux */

.endif
