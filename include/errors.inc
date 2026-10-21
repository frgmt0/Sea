// =====================================================================
// sea/include/errors.inc -- every Sea error message, with its code, and
// the exit statuses of programs, passes and the driver.
//
// CONTRACT FILE. Shared by the passes (messages, through generated DATA,
// DESIGN.md 2.6), both runtimes (_sea_err, the errno text table) and the
// tests. Changes only together with docs/DESIGN.md 2.6.2, which holds the
// same tables, the meaning of every field and the line shapes below. The
// message texts are byte-identical to docs/LANGUAGE.md where LANGUAGE.md
// gives them (DESIGN.md 2.6.2 says which texts are defined here).
//
// Shared by Apple as (arm64) and GNU as (x86_64): `//` comments only at
// the start of a line, trailing comments as /* ... */ (Baysick DESIGN.md
// 3.4). Names are defined with .equiv, so a clash is an assembly error.
// Guarded so it may be included more than once.
//
// LINE SHAPES (read line by line by the DATA generator in sea/tools/,
// DESIGN.md 2.6.2; keep them exact):
//   error record, between ".macro SEA_ERROR_LIST m" and the next ".endm":
//     4 spaces, "\m ", then  code, NAME, phase, at, args, "text"
//   errno record, between ".macro SEA_ERRNO_LIST m" and the next ".endm":
//     4 spaces, "\m ", then  id, NAME, darwin, linux, "text"
//   exit status:  .equiv SEA_EXIT_<NAME>, <decimal>  [ /* comment */ ]
//   Fields are separated by a comma and one space. Inside "text", \"
//   stands for " and \\ for \ (no other escape occurs). Lines starting
//   with // are comments; no other line in a list carries a comment.
//   The generator writes each text into DATA in the DATA escaping of
//   DESIGN.md 2.6.2 (the %-escaping of DESIGN.md 3.1, with " as %22),
//   because a Baysick string constant cannot hold a quote.
// =====================================================================
.ifndef SEA_ERRORS_INC
.equiv SEA_ERRORS_INC, 1

// ---------------------------------------------------------------------
// The error table. code: R 1..99 (dense: the runtime table is indexed by
// it), D and C1 100..199, C2 200..399, CX 400..499, P 500..599; codes
// are never reused or renumbered, new ones are appended in their range.
// phase: R run time (_sea_err), D the driver before any pass, C1 pass 1,
// C2 pass 2a/2b, CX any pass (capacity), P a pass's internal check.
// at: the position a compile-time message reports (DESIGN.md 2.6.2);
// "-" for R and P. args: one letter per substitution, in text order
// (i decimal integer, f f64 as %g, s string, h shape, e errno text);
// "-" for none.
// ---------------------------------------------------------------------
.macro SEA_ERROR_LIST m
// run time (LANGUAGE.md 9.2)
    \m 1, INDEX_OOB, R, -, iii, "index %d out of bounds for dimension %d of extent %d"
    \m 2, SHAPE_MISMATCH, R, -, hh, "shape mismatch: %s vs %s"
    \m 3, SHAPE_EXPECTED, R, -, hh, "shape mismatch: expected %s, got %s"
    \m 4, INT_OVERFLOW, R, -, -, "integer overflow"
    \m 5, INT_DIV_ZERO, R, -, -, "integer division by zero"
    \m 6, CONV_I64, R, -, f, "conversion to i64: %g is not an integer"
    \m 7, RANGE_STEP_ZERO, R, -, -, "range step is zero"
    \m 8, ARRAY_SIZE, R, -, i, "invalid array size %d"
    \m 9, EMPTY_REDUCE, R, -, s, "%s of an empty array"
    \m 10, SINGULAR, R, -, -, "matrix is singular"
    \m 11, NOT_POSDEF, R, -, -, "matrix is not positive definite"
    \m 12, NOT_SYMMETRIC, R, -, -, "matrix is not symmetric"
    \m 13, NOT_SQUARE, R, -, h, "matrix is not square (%s)"
    \m 14, OUT_OF_MEMORY, R, -, -, "out of memory"
    \m 15, STACK_OVERFLOW, R, -, -, "stack overflow"
    \m 16, CANNOT_OPEN, R, -, se, "cannot open '%s': %s"
    \m 17, CANNOT_WRITE, R, -, se, "cannot write '%s': %s"
    \m 18, CANNOT_MKDIR, R, -, se, "cannot create directory '%s': %s"
    \m 19, LINE_STYLE, R, -, s, "invalid line style \"%s\""
    \m 20, COLOR, R, -, s, "invalid color \"%s\""
    \m 21, USER, R, -, s, "%s"
// driver and pass 1: lexical and syntax errors (LANGUAGE.md 3, Appendix A)
    \m 100, LINE_TOO_LONG, D, over, -, "line too long"
    \m 101, ILLEGAL_CHAR, C1, byte, -, "illegal character"
    \m 102, UNTERMINATED_COMMENT, C1, token, -, "unterminated comment"
    \m 103, IDENT_TOO_LONG, C1, token, -, "identifier too long"
    \m 104, BAD_NUMBER, C1, token, -, "invalid numeric literal"
    \m 105, INT_TOO_LARGE, C1, token, -, "integer literal too large"
    \m 106, FLOAT_RANGE, C1, token, -, "float literal out of range"
    \m 107, BAD_ESCAPE, C1, byte, -, "invalid escape"
    \m 108, UNTERMINATED_STRING, C1, token, -, "unterminated string"
    \m 109, CHAINED_COMPARE, C1, token, -, "comparisons cannot be chained"
    \m 110, DOLLAR_OUTSIDE, C1, token, -, "'$' outside an index"
    \m 111, NO_EFFECT, C1, stmt, -, "expression statement has no effect"
    \m 112, UNEXPECTED_TOKEN, C1, token, s, "unexpected token '%s'"
    \m 113, UNEXPECTED_NEWLINE, C1, token, -, "unexpected newline"
    \m 114, UNEXPECTED_EOF, C1, token, -, "unexpected end of file"
// pass 2: names, types and the other rules of LANGUAGE.md 4-11
    \m 200, UNDECLARED, C2, name, s, "undeclared name '%s'"
    \m 201, TYPE_MISMATCH, C2, expr, ss, "type mismatch: expected %s, found %s"
    \m 202, VEC_MAT, C2, expr, -, "cannot combine a vector with a matrix: use .col or .row"
    \m 203, INDEX_I64, C2, expr, -, "index must be i64"
    \m 204, MISSING_FIELD, C2, slit, ss, "missing field '%s' in %s literal"
    \m 205, DUPLICATE_FIELD, C2, init, -, "duplicate field"
    \m 206, UNKNOWN_FIELD, C2, init, -, "unknown field"
    \m 207, NOT_EXHAUSTIVE, C2, match, -, "match is not exhaustive"
    \m 208, UNREACHABLE_PATTERN, C2, arm, -, "unreachable pattern"
    \m 209, REF_ALIAS, C2, ref, -, "ref argument aliases another argument"
    \m 210, FORMAT_ARG, C2, expr, sss, "format \"%s\" expects %s, found %s"
    \m 211, FORMAT_COUNT, C2, call, sii, "format \"%s\" expects %d arguments, found %d"
    \m 212, PREDECLARED, C2, item, -, "redefinition of predeclared name"
    \m 213, SHADOWS_PREDECLARED, C2, binding, -, "local name shadows a predeclared name"
    \m 214, NOT_EXACT_F64, C2, expr, -, "integer constant not exact in f64"
    \m 215, COND_BOOL, C2, expr, -, "condition must be bool"
    \m 216, FIXED_TOO_LARGE, C2, type, -, "fixed-size array too large: use a dynamic array"
    \m 217, SHAPE_MISMATCH_C, C2, expr, hh, "shape mismatch: %s vs %s"
    \m 218, NO_TRANSPOSE, C2, dot, -, "vector has no transpose: use .row or .col"
    \m 219, RAGGED, C2, row, -, "ragged matrix literal"
    \m 220, USE_ROW_COL, C2, row, -, "use .row or .col"
    \m 221, RECURSIVE_STRUCT, C2, struct, -, "recursive struct"
    \m 222, RESERVED_FIELD, C2, fieldname, -, "field name reserved for views"
    \m 223, MISSING_RETURN, C2, fn, -, "missing return"
    \m 224, UNKNOWN_PARAM, C2, narg, -, "unknown parameter"
    \m 225, PARAM_TWICE, C2, narg, -, "parameter given twice"
    \m 226, MISSING_ARG, C2, call, -, "missing argument"
    \m 227, REF_TARGET, C2, ref, -, "ref argument must be a mutable variable, element or field"
    \m 228, ELEM_EFFECTS, C2, effect, -, "effects in elemental function"
    \m 229, UNKNOWN_STRUCT, C2, type, -, "unknown struct type"
    \m 230, MATMUL_VECTORS, C2, expr, -, "vector @ vector is not defined: use sum(a * b)"
    \m 231, INDEX_COUNT, C2, index, ii, "wrong number of indices: expected %d, found %d"
    \m 232, ELEM_RECURSIVE, C2, call, -, "elemental function cannot be recursive"
    \m 233, FORMAT_LITERAL, C2, expr, -, "format must be a string literal"
    \m 234, FORMAT_BAD, C2, str, s, "invalid format conversion \"%s\""
    \m 235, REDEFINITION, C2, binding, s, "redefinition of '%s'"
    \m 236, DEFAULT_MISSING, C2, param, -, "parameter needs a default value"
    \m 237, NOT_CONSTANT, C2, expr, -, "not a constant expression"
    \m 238, ASSIGN_IMMUTABLE, C2, target, s, "cannot assign to immutable '%s'"
    \m 239, BAD_TARGET, C2, target, -, "invalid assignment target"
    \m 240, BAD_OPERANDS, C2, expr, sss, "operator '%s' cannot be applied to %s and %s"
    \m 241, BAD_OPERAND, C2, expr, ss, "operator '%s' cannot be applied to %s"
    \m 242, TOO_MANY_ARGS, C2, call, -, "too many arguments"
    \m 243, NO_OVERLOAD, C2, call, ss, "no overload of '%s' accepts (%s)"
    \m 244, NOT_FUNCTION, C2, call, s, "'%s' is not a function"
    \m 245, MULTI_VALUE, C2, call, -, "multiple-result call used as a value"
    \m 246, RESULT_COUNT, C2, results, ii, "wrong number of results: expected %d, found %d"
    \m 247, BREAK_OUTSIDE, C2, break, -, "break outside a loop"
    \m 248, CONTINUE_OUTSIDE, C2, continue, -, "continue outside a loop"
    \m 249, NO_FIELD, C2, dot, ss, "no field '%s' in %s"
    \m 250, NOT_INDEXABLE, C2, index, s, "%s cannot be indexed"
    \m 251, NOT_ITERABLE, C2, expr, s, "cannot iterate over %s"
    \m 252, CANNOT_INFER, C2, binding, -, "type cannot be inferred: add a type annotation"
    \m 253, ELEM_RESULT, C2, fn, -, "elemental function result must be f64, i64 or bool"
    \m 254, REF_NEEDED, C2, expr, s, "argument for ref parameter '%s' must be marked ref"
    \m 255, REF_UNEXPECTED, C2, ref, s, "'%s' is not a ref parameter"
    \m 256, PROJECTION, C2, dot, ss, "cannot project field '%s' of type %s"
    \m 257, VIEW_RANK, C2, dot, ss, "view .%s is not defined for %s"
    \m 258, ELEMENT_TYPE, C2, type, s, "arrays cannot hold %s"
// phase rule (DESIGN.md 2.6.2, 8): a construct the compiler does not implement yet;
// retired (never produced, code kept reserved) once Sea v1 is complete
    \m 259, NOT_SUPPORTED, C2, construct, s, "not supported yet: %s"
// any pass: capacity limits (DESIGN.md 2.7)
    \m 400, TOO_LARGE, CX, here, s, "program too large: %s"
// passes: internal consistency checks, status SEA_EXIT_PASS_INTERNAL (DESIGN.md 2.2, 3.2, 3.3)
    \m 500, TRUNCATED, P, -, -, "internal error: truncated input"
    \m 501, BAD_HEADER, P, -, -, "internal error: bad header"
    \m 502, BAD_RECORD, P, -, -, "internal error: bad record"
    \m 503, BAD_TREE, P, -, -, "internal error: bad tree"
    \m 504, BAD_DATA, P, -, -, "internal error: bad DATA table"
.endm

// One past the last run-time code: _sea_err accepts 1 .. SEA_E_RT_END-1.
.equiv SEA_E_RT_END,            22

// ---------------------------------------------------------------------
// The errno text table (LANGUAGE.md 9.2: the reason in cannot open /
// cannot write / cannot create directory). id: dense from 0; darwin,
// linux: the host errno value on arm64-macos and x86_64-linux (-1: none).
// A host errno not in the table prints the text of id 0.
// ---------------------------------------------------------------------
.macro SEA_ERRNO_LIST m
    \m 0, UNKNOWN, -1, -1, "unknown error"
    \m 1, EPERM, 1, 1, "Operation not permitted"
    \m 2, ENOENT, 2, 2, "No such file or directory"
    \m 3, EIO, 5, 5, "Input/output error"
    \m 4, EACCES, 13, 13, "Permission denied"
    \m 5, EEXIST, 17, 17, "File exists"
    \m 6, ENOTDIR, 20, 20, "Not a directory"
    \m 7, EISDIR, 21, 21, "Is a directory"
    \m 8, EINVAL, 22, 22, "Invalid argument"
    \m 9, ENFILE, 23, 23, "Too many open files in system"
    \m 10, EMFILE, 24, 24, "Too many open files"
    \m 11, EFBIG, 27, 27, "File too large"
    \m 12, ENOSPC, 28, 28, "No space left on device"
    \m 13, EROFS, 30, 30, "Read-only file system"
    \m 14, EPIPE, 32, 32, "Broken pipe"
    \m 15, ENAMETOOLONG, 63, 36, "File name too long"
    \m 16, ELOOP, 62, 40, "Too many levels of symbolic links"
    \m 17, EDQUOT, 69, 122, "Disk quota exceeded"
.endm

// Number of errno records (ids 0 .. SEA_ERRNO_COUNT-1).
.equiv SEA_ERRNO_COUNT,         18

// ---- Exit statuses (LANGUAGE.md 9.4; DESIGN.md 2.2) ----------------------
// compiled program
.equiv SEA_EXIT_RUN_OK,         0   /* normal end */
.equiv SEA_EXIT_RUN_ERROR,      1   /* run-time error, including error() and a failed write */
// compiler pass (a Baysick program)
.equiv SEA_EXIT_PASS_OK,        0   /* success; the output ends with #end */
.equiv SEA_EXIT_PASS_BAYSICK,   1   /* a Baysick run-time error inside the pass */
.equiv SEA_EXIT_PASS_COMPILE,   10  /* a Sea compile error, diagnostic on stderr (STOP 10) */
.equiv SEA_EXIT_PASS_INTERNAL,  11  /* a phase P check failed (STOP 11) */
// driver (sea)
.equiv SEA_EXIT_OK,             0   /* success */
.equiv SEA_EXIT_COMPILE,        1   /* Sea compile error */
.equiv SEA_EXIT_USAGE,          2   /* usage or file error */
.equiv SEA_EXIT_TOOLCHAIN,      3   /* as / ld / xcrun missing or failing */
.equiv SEA_EXIT_INTERNAL,       4   /* pass status 1 or 11, a missing #end, out of memory */

// ---- Runtime message table record (SEA_EMIT_ERRMSG_TABLE) ----------------
.equiv SEA_ERRTAB_MSG,          0   /* ptr  NUL-terminated message text */
.equiv SEA_ERRTAB_ARGS,         8   /* ptr  NUL-terminated args letters ("" for none) */
.equiv SEA_ERRTAB_SIZE,         16  /* record k is at table + 16*k; record 0 is zero */

// ---- Errno table record (SEA_EMIT_ERRNO_TABLE) ----------------------------
.equiv SEA_ERRNO_HOST,          0   /* i64  host errno value (-1 in record 0) */
.equiv SEA_ERRNO_TEXT,          8   /* ptr  NUL-terminated reason text */
.equiv SEA_ERRNO_SIZE,          16  /* record id is at table + 16*id */

// ---- Definitions of the names ----------------------------------------
// Error codes: SEA_E_<NAME>; errno ids: SEA_ERRNO_<NAME>.
.macro SEA_ERRDEF_E code, name, ph, at, args, text
.equiv SEA_E_\name, \code
.endm
.macro SEA_ERRDEF_N id, name, darwin, linux, text
.equiv SEA_ERRNO_\name, \id
.endm
SEA_ERROR_LIST SEA_ERRDEF_E
SEA_ERRNO_LIST SEA_ERRDEF_N

// ---------------------------------------------------------------------
// SEA_EMIT_ERRMSG_TABLE name
//   Emits, in the CURRENT section (Mach-O: __DATA,__const; ELF:
//   .section .data.rel.ro,"aw",@progbits), the 8-byte aligned table
//   `name` of SEA_E_RT_END records of SEA_ERRTAB_SIZE bytes, indexed by
//   run-time code (record 0 is zero), followed by the strings. Labels
//   other than `name` are sea_errmsg_<code> and sea_errargs_<code>
//   (local symbols), so instantiate it at most once per object file.
//   Both runtimes' _sea_err instantiate it, so the texts cannot diverge.
// ---------------------------------------------------------------------
.macro SEA_ERRTAB_REC code, name, ph, at, args, text
.ifc \ph,R
    .quad sea_errmsg_\code, sea_errargs_\code
.endif
.endm
.macro SEA_ERRTAB_TXT code, name, ph, at, args, text
.ifc \ph,R
sea_errmsg_\code: .asciz "\text"
.ifc \args,-
sea_errargs_\code: .asciz ""
.else
sea_errargs_\code: .asciz "\args"
.endif
.endif
.endm
.macro SEA_EMIT_ERRMSG_TABLE name
    .p2align 3
\name:
    .quad 0, 0
    SEA_ERROR_LIST SEA_ERRTAB_REC
    SEA_ERROR_LIST SEA_ERRTAB_TXT
    .p2align 3
.endm

// ---------------------------------------------------------------------
// SEA_EMIT_ERRNO_TABLE name, host
//   host: darwin (arm64-macos runtime) or linux (x86_64-linux runtime).
//   Emits, in the CURRENT section (as above), the 8-byte aligned table
//   `name` of SEA_ERRNO_COUNT records of SEA_ERRNO_SIZE bytes, indexed by
//   id, holding that host's errno values, followed by the texts (labels
//   sea_errno_text_<id>; at most once per object file).
// ---------------------------------------------------------------------
.macro SEA_ERRNOTAB_darwin id, name, darwin, linux, text
    .quad \darwin, sea_errno_text_\id
.endm
.macro SEA_ERRNOTAB_linux id, name, darwin, linux, text
    .quad \linux, sea_errno_text_\id
.endm
.macro SEA_ERRNOTAB_TXT id, name, darwin, linux, text
sea_errno_text_\id: .asciz "\text"
.endm
.macro SEA_EMIT_ERRNO_TABLE name, host
    .p2align 3
\name:
    SEA_ERRNO_LIST SEA_ERRNOTAB_\host
    SEA_ERRNO_LIST SEA_ERRNOTAB_TXT
    .p2align 3
.endm

.endif
