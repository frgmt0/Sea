# sea/tests/rt/x86_64_linux/rt_vmath_abi.s -- the 2-lane vector elementary functions sea_log_x sea_exp_x sea_sin_x sea_cos_x sea_pow_x sea_hypot_x (DESIGN.md 2.12.8, 4.10.1, 6.2 "Runtime tests (7d)"): for each entry and each case (common lanes only, a rare lane in each position, rare lanes only, including the rare lanes found after the common computation: pow's |ehi| >= 512 and hypot's subnormal result) the probe checks that %rbx %rbp %r12-%r15 and %rsp are preserved (System V and 2.12.8's ABI), that the MXCSR control bits are unchanged and the direction flag clear, that nothing below 512 bytes under the return address was written (two canary patterns), and that every result lane equals the scalar entry of rt_math.s on that lane's operands, bit for bit; each case prints its name and ok, a failure prints what failed and exits 1
.include "rt.inc"

# ---- test helpers ----
# Print a literal text (caller-saved registers clobbered).
.macro TXT text
    .pushsection .rodata
.Ltxt\@: .asciz "\text"
    .popsection
    leaq .Ltxt\@(%rip), %rdi
    call put_cstr
.endm
# sea_main's frame: %rbp, %rbx, %r12-%r15 saved, 56 bytes of locals at 0(%rsp)
# (entered at %rsp = 8 (mod 16), so %rsp = 0 (mod 16) after it).
.macro PROLOGUE
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $56, %rsp
.endm
.macro EPILOGUE
    addq $56, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.endm

# The case records (.data.rel.ro): the entry, its scalar entry, the lane count, the
# case name (a C string), the four x lanes and the four y lanes (bit patterns; lanes
# beyond the lane count are not used).
.equ REC_ENTRY,         0
.equ REC_SCALAR,        8
.equ REC_LANES,         16
.equ REC_NAME,          24
.equ REC_X,             32
.equ REC_Y,             64
.equ REC_SIZE,          96
.macro REC entry, scalar, lanes, name, x0, x1, y0, y1
    .quad \entry, \scalar, \lanes, .Lrn\@
    .quad \x0, \x1, 0, 0
    .quad \y0, \y1, 0, 0
    .pushsection .rodata
.Lrn\@: .asciz "\name"
    .popsection
.endm
# CASES entry, scalar: the eight 2-lane cases of one entry from four common
# operand pairs (c) and four rare pairs (r; r2 and r3 rare only after the
# common computation for pow and hypot): c0 c1; c2 c3; r0 c1; c0 r1; r2 c3;
# c2 r3; r0 r1; r2 r3.
.macro CASES entry, scalar, cx0, cy0, cx1, cy1, cx2, cy2, cx3, cy3, rx0, ry0, rx1, ry1, rx2, ry2, rx3, ry3
    REC \entry, \scalar, 2, "\entry common 1", \cx0, \cx1, \cy0, \cy1
    REC \entry, \scalar, 2, "\entry common 2", \cx2, \cx3, \cy2, \cy3
    REC \entry, \scalar, 2, "\entry rare lane 0", \rx0, \cx1, \ry0, \cy1
    REC \entry, \scalar, 2, "\entry rare lane 1", \cx0, \rx1, \cy0, \ry1
    REC \entry, \scalar, 2, "\entry rare lane 0 b", \rx2, \cx3, \ry2, \cy3
    REC \entry, \scalar, 2, "\entry rare lane 1 b", \cx2, \rx3, \cy2, \ry3
    REC \entry, \scalar, 2, "\entry rare 1", \rx0, \rx1, \ry0, \ry1
    REC \entry, \scalar, 2, "\entry rare 2", \rx2, \rx3, \ry2, \ry3
.endm

# The patterns the probe puts in the callee-saved registers, and the canaries.
.equ PAT_RBX,           0x1B1B1B1B1B1B1B1B
.equ PAT_RBP,           0x2B2B2B2B2B2B2B2B
.equ PAT_R12,           0x3C3C3C3C3C3C3C3C
.equ PAT_R13,           0x4D4D4D4D4D4D4D4D
.equ PAT_R14,           0x5E5E5E5E5E5E5E5E
.equ PAT_R15,           0x6F6F6F6F6F6F6F6F
.equ CANARY_A,          0xA5C3A5C3A5C3A5C3
.equ CANARY_B,          0x5A3C5A3C5A3C5A3C
.equ CANARY_BYTES,      2048        # filled below the return address
.equ STACK_BOUND,       512         # DESIGN.md 2.12.8

    .text
# put_cstr -- print a NUL-terminated text (%rdi). Callee-saved used: %rbx.
    .p2align 4
put_cstr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    call strlen@PLT
    movq %rax, %rsi
    movq %rbx, %rdi
    call sea_out_write
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# put_hex -- print %rdi as 16 upper-case hexadecimal digits (the bits of an f64).
#   Frame: 8 (%rbp) + 16 bytes of digits.
    .p2align 4
put_hex:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movl $16, %ecx
1:  movl %edi, %eax
    andl $15, %eax
    leaq .Lput_hexd(%rip), %rdx
    movb (%rdx,%rax), %al
    decl %ecx
    movb %al, (%rsp,%rcx)
    shrq $4, %rdi
    testl %ecx, %ecx
    jnz 1b
    movq %rsp, %rdi
    movl $16, %esi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret
    .pushsection .rodata
.Lput_hexd: .ascii "0123456789ABCDEF"
    .popsection

# ---------------------------------------------------------------------
# probe -- call the vector entry of one case record under observation.
#   Inputs : %rdi = the record, %rsi = the canary pattern
#   Outputs: .Lres = the result lanes; .Lbad = a bit per callee-saved
#            register changed (0 %rbx, 1 %rbp, 2 %r12, 3 %r13, 4 %r14,
#            5 %r15, 6 %rsp); .Ldepth = the bytes written below the
#            return address (0 if none); .Lmx0/.Lmx1 = MXCSR before and
#            after; .Lflags = RFLAGS after the call
#   Clobbers: the caller-saved registers
#   Callee-saved used: %r12 (the record), %r13 (the pattern) until the
#            call, then all of them hold the test patterns
#   Frame  : 8 (%rbp) + 40 (callee-saved) + 8; the canary area is the
#            CANARY_BYTES below the slot of the call's return address
# ---------------------------------------------------------------------
    .p2align 4
probe:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16): the call site
    movq %rdi, %r12
    movq %rsi, %r13
    # The canary: CANARY_BYTES ending at -8(%rsp), the return address's slot.
    leaq -8-CANARY_BYTES(%rsp), %rdi
    movl $CANARY_BYTES/8, %ecx
    movq %r13, %rax
    cld
    rep stosq
    stmxcsr .Lmx0(%rip)
    # The operands (both, whatever the entry reads).
    movupd REC_X(%r12), %xmm0
    movupd REC_Y(%r12), %xmm1
    movq REC_ENTRY(%r12), %r11
    movq %rsp, .Lsp(%rip)
    movabsq $PAT_RBX, %rbx
    movabsq $PAT_RBP, %rbp
    movabsq $PAT_R12, %r12
    movabsq $PAT_R13, %r13
    movabsq $PAT_R14, %r14
    movabsq $PAT_R15, %r15
    call *%r11
    pushfq
    popq %rcx
    movq %rcx, .Lflags(%rip)
    stmxcsr .Lmx1(%rip)
    movupd %xmm0, .Lres(%rip)
    # Which callee-saved registers changed.
    xorl %eax, %eax
    movabsq $PAT_RBX, %rcx
    cmpq %rcx, %rbx
    je 1f
    orl $1, %eax
1:  movabsq $PAT_RBP, %rcx
    cmpq %rcx, %rbp
    je 1f
    orl $2, %eax
1:  movabsq $PAT_R12, %rcx
    cmpq %rcx, %r12
    je 1f
    orl $4, %eax
1:  movabsq $PAT_R13, %rcx
    cmpq %rcx, %r13
    je 1f
    orl $8, %eax
1:  movabsq $PAT_R14, %rcx
    cmpq %rcx, %r14
    je 1f
    orl $16, %eax
1:  movabsq $PAT_R15, %rcx
    cmpq %rcx, %r15
    je 1f
    orl $32, %eax
1:  cmpq .Lsp(%rip), %rsp
    je 1f
    orl $64, %eax
    movq .Lsp(%rip), %rsp           # back to the call site's %rsp
1:  movq %rax, .Lbad(%rip)
    # The lowest canary word changed: depth = (return slot) - its address.
    movq .Lsp(%rip), %rdx
    leaq -8-CANARY_BYTES(%rdx), %rdi   # the lowest canary word
    leaq -8(%rdx), %rsi             # the return address's slot (excluded)
    movq .Lpat(%rip), %rcx
    xorl %eax, %eax
2:  cmpq %rsi, %rdi
    jae 3f
    cmpq (%rdi), %rcx
    jne 4f
    addq $8, %rdi
    jmp 2b
4:  movq %rsi, %rax
    subq %rdi, %rax
3:  movq %rax, .Ldepth(%rip)
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# sea_main -- every case record: the probe with both canaries, the checks,
#   then each lane against the scalar entry.
#   Callee-saved used: %rbx (the record), %r12 (the end), %r13 (the
#   deepest write), %r14 (the lane), %r15 (the lane count)
# ---------------------------------------------------------------------
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    leaq .Lrecs(%rip), %rbx
    leaq .Lrecs_end(%rip), %r12
1:  cmpq %r12, %rbx
    jae 9f
    # Both canaries: the deepest write of the two runs.
    movabsq $CANARY_B, %rax
    movq %rax, .Lpat(%rip)
    movq %rbx, %rdi
    movq %rax, %rsi
    call probe
    movq .Ldepth(%rip), %r13
    cmpq $0, .Lbad(%rip)
    jne 20f
    movabsq $CANARY_A, %rax
    movq %rax, .Lpat(%rip)
    movq %rbx, %rdi
    movq %rax, %rsi
    call probe
    cmpq $0, .Lbad(%rip)
    jne 20f
    cmpq .Ldepth(%rip), %r13
    jae 2f
    movq .Ldepth(%rip), %r13
2:  cmpq $STACK_BOUND, %r13
    ja 21f
    # MXCSR control bits (6-15) unchanged; the direction flag (bit 10) clear.
    movl .Lmx0(%rip), %eax
    xorl .Lmx1(%rip), %eax
    testl $0xFFC0, %eax
    jnz 22f
    testq $0x400, .Lflags(%rip)
    jnz 23f
    # Every lane against the scalar entry (the result of the second run).
    movq REC_LANES(%rbx), %r15
    xorl %r14d, %r14d
3:  cmpq %r15, %r14
    jae 4f
    movsd REC_X(%rbx,%r14,8), %xmm0
    movsd REC_Y(%rbx,%r14,8), %xmm1
    call *REC_SCALAR(%rbx)
    movq %xmm0, %rax
    leaq .Lres(%rip), %rcx
    cmpq (%rcx,%r14,8), %rax
    jne 24f
    incq %r14
    jmp 3b
4:  movq REC_NAME(%rbx), %rdi
    call put_cstr
    TXT " ok\n"
    addq $REC_SIZE, %rbx
    jmp 1b
9:  EPILOGUE
20: movq REC_NAME(%rbx), %rdi
    call put_cstr
    TXT ": callee-saved registers changed, mask "
    movq .Lbad(%rip), %rdi
    call put_hex
    jmp 30f
21: movq REC_NAME(%rbx), %rdi
    call put_cstr
    TXT ": wrote below 512 bytes under the return address, depth "
    movq %r13, %rdi
    call put_hex
    jmp 30f
22: movq REC_NAME(%rbx), %rdi
    call put_cstr
    TXT ": MXCSR control bits changed"
    jmp 30f
23: movq REC_NAME(%rbx), %rdi
    call put_cstr
    TXT ": direction flag set"
    jmp 30f
24: movq %rax, %r13                 # the scalar entry's result
    movq REC_NAME(%rbx), %rdi
    call put_cstr
    TXT ": lane "
    movq %r14, %rdi
    call put_hex
    TXT " x="
    movq REC_X(%rbx,%r14,8), %rdi
    call put_hex
    TXT " y="
    movq REC_Y(%rbx,%r14,8), %rdi
    call put_hex
    TXT " scalar="
    movq %r13, %rdi
    call put_hex
    TXT " vector="
    leaq .Lres(%rip), %rcx
    movq (%rcx,%r14,8), %rdi
    call put_hex
30: TXT "\n"
    call sea_out_flush
    movl $1, %edi                   # status 1
    call _exit@PLT

    .bss
    .p2align 5
.Lres:   .space 32                  # the result lanes of the last probe
.Lsp:    .space 8                   # the call site's %rsp
.Lbad:   .space 8
.Ldepth: .space 8
.Lpat:   .space 8                   # the canary pattern of the probe
.Lflags: .space 8
.Lmx0:   .space 4
.Lmx1:   .space 4

# Operand patterns (the bits of the values named).
.equ D_ZERO,    0x0000000000000000  # +0
.equ D_ONE,     0x3FF0000000000000  # 1.0
.equ D_MONE,    0xBFF0000000000000  # -1.0
.equ D_HALF,    0x3FE0000000000000  # 0.5
.equ D_TWO,     0x4000000000000000  # 2.0
.equ D_MTWO,    0xC000000000000000  # -2.0
.equ D_THREE,   0x4008000000000000  # 3.0
.equ D_FOUR,    0x4010000000000000  # 4.0
.equ D_FIVE,    0x4014000000000000  # 5.0
.equ D_TEN,     0x4024000000000000  # 10.0
.equ D_M3,      0xC008000000000000  # -3.0
.equ D_M325,    0xC00A000000000000  # -3.25
.equ D_100,     0x4059000000000000  # 100.0
.equ D_1005,    0x4059200000000000  # 100.5
.equ D_075,     0x3FE8000000000000  # 0.75
.equ D_15,      0x3FF8000000000000  # 1.5
.equ D_700,     0x4085E00000000000  # 700.0 (exp: >= 512)
.equ D_M800,    0xC089000000000000  # -800.0
.equ D_TENTH,   0x3FB999999999999A  # 0.1
.equ D_1E300,   0x7E37E43C8800759C  # 1e300
.equ D_1E6,     0x412E848000000000  # 1e6
.equ D_2M66,    0x3BD0000000000000  # 2^-66 (exp: |x| < 2^-54)
.equ D_2M80,    0x3AF0000000000000  # 2^-80 (pow: |ehi| < 2^-54)
.equ D_2M100,   0x39B0000000000000  # 2^-100 (sin/cos: |x| < 2^-27)
.equ D_2P30,    0x41D0000000000000  # 2^30 (sin/cos: >= 2^23)
.equ D_M2P74,   0xC490000000000000  # -2^74
.equ D_2P1000,  0x7E70000000000000  # 2^1000 (pow 2^1000^10: |ehi| >= 512)
.equ D_2P600,   0x6570000000000000  # 2^600 (hypot: > 2^500)
.equ D_2P599,   0x6560000000000000  # 2^599
.equ D_2M600,   0x1A70000000000000  # 2^-600 (hypot: < 2^-500)
.equ D_3M601,   0x1A68000000000000  # 1.5 * 2^-600
.equ D_2M1060,  0x0000000000004000  # 2^-1060, subnormal (hypot: subnormal result)
.equ D_2M1061,  0x0000000000002000  # 2^-1061
.equ D_SUBMIN,  0x0000000000000001  # 2^-1074
.equ D_INF,     0x7FF0000000000000  # +Inf
.equ D_MINF,    0xFFF0000000000000  # -Inf
.equ D_NAN,     0x7FF8000000000000  # NaN
.equ D_NANP,    0x7FF0000000000123  # NaN with a payload
.equ D_MNAN,    0xFFF8000000000000  # -NaN

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Lrecs:
    #     entry, scalar; c0 (x, y), c1, c2, c3; r0, r1, r2, r3 (y = 0 for one operand)
    CASES sea_exp_x, sea_exp, D_HALF,0, D_M325,0, D_100,0, D_2M66,0, D_NANP,0, D_700,0, D_M800,0, D_INF,0
    CASES sea_log_x, sea_log, D_TWO,0, D_TENTH,0, D_1E300,0, D_ONE,0, D_MONE,0, D_ZERO,0, D_SUBMIN,0, D_INF,0
    CASES sea_sin_x, sea_sin, D_HALF,0, D_MTWO,0, D_2M100,0, D_1E6,0, D_2P30,0, D_INF,0, D_MNAN,0, D_M2P74,0
    CASES sea_cos_x, sea_cos, D_HALF,0, D_MTWO,0, D_2M100,0, D_1E6,0, D_2P30,0, D_INF,0, D_MNAN,0, D_M2P74,0
    CASES sea_pow_x, sea_pow, D_TWO,D_HALF, D_TEN,D_M3, D_075,D_1005, D_15,D_2M80, D_MTWO,D_THREE, D_ZERO,D_MONE, D_2P1000,D_TEN, D_NAN,D_ONE
    CASES sea_hypot_x, sea_hypot, D_THREE,D_FOUR, D_2P600,D_2P599, D_2M600,D_3M601, D_FIVE,D_ZERO, D_INF,D_NAN, D_NAN,D_ONE, D_2M1060,D_2M1061, D_ONE,D_MINF
.Lrecs_end:
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0

    .section .note.GNU-stack,"",@progbits
