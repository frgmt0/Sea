// =====================================================================
// sea/include/limits.inc -- Sea's limits: language limits, compiler
// capacity limits, intermediate-file limits and runtime sizes.
//
// CONTRACT FILE. Shared by the passes (through generated DATA, DESIGN.md
// 2.6), both runtimes and the tests. Changes only together with
// docs/DESIGN.md 2.6.1 (the table of these names) and the sections it
// cites (LANGUAGE.md 3.1, 3.3, 3.5, 4.1, 4.5, 6.5, 6.8, 8.6, 10.5, 11.3,
// 11.4; DESIGN.md 2.4, 2.7, 3.1, 3.2, 3.9, 4.1, 4.6).
//
// Shared by Apple as (arm64) and GNU as (x86_64): `//` comments only at
// the start of a line, trailing comments as /* ... */ (Baysick DESIGN.md
// 3.4). Every name is defined with .equiv, so a clash with any other
// definition (for instance in Baysick's runtime.inc) is an assembly error.
// Guarded so it may be included more than once.
// =====================================================================
.ifndef SEA_LIMITS_INC
.equiv SEA_LIMITS_INC, 1

// ---- Language limits (LANGUAGE.md) -----------------------------------
.equiv SEA_LIM_LINE_BYTES,      4096        /* bytes per source line after CR removal -> line too long (3.1) */
.equiv SEA_LIM_IDENT_BYTES,     63          /* bytes per identifier -> identifier too long (3.3) */
.equiv SEA_LIM_UESC_DIGITS,     6           /* hex digits in \u{...} -> invalid escape (3.5) */
.equiv SEA_LIM_UESC_MAX,        0x10FFFF    /* largest code point of \u{...} -> invalid escape (3.5) */
.equiv SEA_LIM_FIXED_ELEMS,     256         /* elements of T[n] / T[r,c]; larger literals are dynamic (4.5, 6.9) */
.equiv SEA_LIM_EXTENT,          2147483647  /* largest extent of a dynamic array, 2^31 - 1 (4.5) */
.equiv SEA_LIM_STR_BYTES,       2147483647  /* largest str length in bytes, 2^31 - 1 (4.1) */
.equiv SEA_LIM_POWK,            4           /* x ^ k by pinned multiplications for constant integral |k| <= 4 (6.5) */
.equiv SEA_LIM_FIXED_MATMUL_E,  8           /* fixed-size @ is class E when every extent is <= 8 (6.8) */
.equiv SEA_LIM_INLINE_STMTS,    50          /* inlining rule (c): at most 50 statements (8.6) */
.equiv SEA_SUM_LANES,           8           /* accumulators of the pinned summation order (10.5) */

// ---- Compiler capacity limits (DESIGN.md 2.7) -> program too large: %s
.equiv SEA_LIM_NODES,           99999       /* syntax-tree nodes per compilation, prelude included */
.equiv SEA_LIM_SYMBOLS,         49999       /* symbols */
.equiv SEA_LIM_TYPES,           19999       /* types */
.equiv SEA_LIM_CONSTS,          19999       /* numeric constants */
.equiv SEA_LIM_STRINGS,         199999      /* distinct strings */
.equiv SEA_LIM_NESTING,         64          /* expression nesting depth */
.equiv SEA_LIM_PARAMS,          64          /* parameters per function */
.equiv SEA_LIM_FIELDS,          64          /* fields per struct */
.equiv SEA_LIM_RESULTS,         64          /* results per function */
// LIR passes 3a, 3b, 4 (DESIGN.md 2.7, tables of the LIR passes)
.equiv SEA_LIM_LIR_INSTRS,      199999      /* LIR instructions per function; pass 3a buffered records */
.equiv SEA_LIM_LIR_OPERANDS,    799999      /* operand fields of one function's instructions */
.equiv SEA_LIM_LIR_REGS,        99999       /* virtual registers per function */
.equiv SEA_LIM_LIR_BLOCKS,      9999        /* loop/do/if/ifz constructs per function */
.equiv SEA_LIM_LIR_SLOTS,       9999        /* stack slots per function */
.equiv SEA_LIM_LIR_IMMS,        199999      /* li/lf constants per function */
.equiv SEA_LIM_LIR_LABELS,      49999       /* LIR data labels per compilation */
.equiv SEA_LIM_LIR_SITES,       49999       /* distinct run-time error sites per compilation */

// ---- Intermediate files (DESIGN.md 2.4, 3.1, 3.2, 3.9) ------------------
.equiv SEA_FILE_VERSION,        1           /* the version field of the #sea header record (3.2) */
.equiv SEA_LIM_RECORD_BYTES,    65536       /* bytes per record line, excluding LF (3.1) */
.equiv SEA_LIM_DEC_FIELD,       999999999   /* largest u field; i fields in decimal have |v| <= this (2.4, 3.1) */
.equiv SEA_LIM_PASSES_LINE,     255         /* bytes per line of passes.txt, excluding LF (3.9) */

// ---- Runtime sizes (LANGUAGE.md 11.3, 11.4; DESIGN.md 4.1, 4.6) ----------
.equiv SEA_STDOUT_BUF_BYTES,    65536       /* standard-output buffer (LANGUAGE.md 11.3) */
.equiv SEA_JSON_BUF_BYTES,      65536       /* write_json file buffer (LANGUAGE.md 11.4) */
.equiv SEA_STACK_BYTES,         67108864    /* program stack, 64 MiB, plus a guard page (4.6) */
.equiv SEA_SMALL_MAX_BYTES,     4096        /* largest small block; larger blocks come from mmap (4.1) */
.equiv SEA_CHUNK_BYTES,         1048576     /* chunk that refills the small-block free lists, 1 MiB (4.1) */
.equiv SEA_LCACHE_PER_CLASS,    8           /* cached free large blocks per power-of-two size class (4.1) */
.equiv SEA_LCACHE_MAX_BYTES,    268435456   /* cached free large blocks in all, 256 MiB (4.1) */

.endif
