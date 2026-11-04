# sea/tests/rt/x86_64_linux/rt_lib_err_f64_hex.s -- sea_parse_f64, parse_f64("0x1p3"): PARSE_F64 {s}; reported at its site (m.sea:38, site 1), status 1, standard output flushed first (DESIGN.md 2.15.2, 2.15.5)
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .text
# sea_main -- print "before", then the failing call (never returns).
#   Frame: 8 bytes (%rbp); %rsp = 0 (mod 16) at the calls
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    pushq %rbp
    movq %rsp, %rbp
    leaq .Lbefore(%rip), %rdi
    movl $7, %esi
    call sea_out_write              # "before\n", buffered
    leaq .Larg0(%rip), %rdi
    movq $1, %rsi                   # site 1
    call sea_parse_f64
    leaq .Lafter(%rip), %rdi        # not reached
    movl $12, %esi
    call sea_out_write
    popq %rbp
    ret

    .section .rodata
.Lbefore: .ascii "before\n"
.Lafter:  .ascii "not reached\n"
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Larg0:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .byte 0x30, 0x78, 0x31, 0x70, 0x33
    .p2align 3
.Lfile:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .byte 0x6d, 0x2e, 0x73, 0x65, 0x61
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lfile, 1                 # site 0
    .quad .Lfile, 38                # site 1

    .section .note.GNU-stack,"",@progbits
