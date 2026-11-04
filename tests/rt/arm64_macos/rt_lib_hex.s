// =====================================================================
// sea/tests/rt/arm64_macos/rt_lib_hex.s -- runtime test of rt_fmt.s: %x and %X of i64
// (L-mm, Decision 150 (d), LANGUAGE.md 11.1): 270 cases, 9 values x 30 conversions
// (0, 1, 255, -1, INT64_MIN, INT64_MAX and others; width, precision, - 0 # flags, + and
// space ignored). Expected bytes (rt_lib_hex.out) are C99's 7.21.6.1 definition,
// computed independently of the runtime and cross-checked against Python's %-operator.
// Each case is [<text>]\n with the conversion as written; case k has site index k.
// Run by tests/rt/run_rt.sh. 
// =====================================================================
.include "limits.inc"
.include "rt.inc"
    .section __TEXT,__text,regular,pure_instructions

// _sea_main -- one _sea_printf call per case, in order.
//   Frame: 16 bytes (frame record); callee-saved used: none
    .globl _sea_main
    .p2align 2
_sea_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    // case 0: %x of 0
    adrp x0, Ltf_fmt_0@PAGE
    add x0, x0, Ltf_fmt_0@PAGEOFF
    adrp x1, Ltf_slots_0@PAGE
    add x1, x1, Ltf_slots_0@PAGEOFF
    mov x2, #0
    bl _sea_printf
    // case 1: %x of 1
    adrp x0, Ltf_fmt_1@PAGE
    add x0, x0, Ltf_fmt_1@PAGEOFF
    adrp x1, Ltf_slots_1@PAGE
    add x1, x1, Ltf_slots_1@PAGEOFF
    mov x2, #1
    bl _sea_printf
    // case 2: %x of 255
    adrp x0, Ltf_fmt_2@PAGE
    add x0, x0, Ltf_fmt_2@PAGEOFF
    adrp x1, Ltf_slots_2@PAGE
    add x1, x1, Ltf_slots_2@PAGEOFF
    mov x2, #2
    bl _sea_printf
    // case 3: %x of -1
    adrp x0, Ltf_fmt_3@PAGE
    add x0, x0, Ltf_fmt_3@PAGEOFF
    adrp x1, Ltf_slots_3@PAGE
    add x1, x1, Ltf_slots_3@PAGEOFF
    mov x2, #3
    bl _sea_printf
    // case 4: %x of -9223372036854775808
    adrp x0, Ltf_fmt_4@PAGE
    add x0, x0, Ltf_fmt_4@PAGEOFF
    adrp x1, Ltf_slots_4@PAGE
    add x1, x1, Ltf_slots_4@PAGEOFF
    mov x2, #4
    bl _sea_printf
    // case 5: %x of 9223372036854775807
    adrp x0, Ltf_fmt_5@PAGE
    add x0, x0, Ltf_fmt_5@PAGEOFF
    adrp x1, Ltf_slots_5@PAGE
    add x1, x1, Ltf_slots_5@PAGEOFF
    mov x2, #5
    bl _sea_printf
    // case 6: %x of 3735928559
    adrp x0, Ltf_fmt_6@PAGE
    add x0, x0, Ltf_fmt_6@PAGEOFF
    adrp x1, Ltf_slots_6@PAGE
    add x1, x1, Ltf_slots_6@PAGEOFF
    mov x2, #6
    bl _sea_printf
    // case 7: %x of 16
    adrp x0, Ltf_fmt_7@PAGE
    add x0, x0, Ltf_fmt_7@PAGEOFF
    adrp x1, Ltf_slots_7@PAGE
    add x1, x1, Ltf_slots_7@PAGEOFF
    mov x2, #7
    bl _sea_printf
    // case 8: %x of 419385573
    adrp x0, Ltf_fmt_8@PAGE
    add x0, x0, Ltf_fmt_8@PAGEOFF
    adrp x1, Ltf_slots_8@PAGE
    add x1, x1, Ltf_slots_8@PAGEOFF
    mov x2, #8
    bl _sea_printf
    // case 9: %X of 0
    adrp x0, Ltf_fmt_9@PAGE
    add x0, x0, Ltf_fmt_9@PAGEOFF
    adrp x1, Ltf_slots_9@PAGE
    add x1, x1, Ltf_slots_9@PAGEOFF
    mov x2, #9
    bl _sea_printf
    // case 10: %X of 1
    adrp x0, Ltf_fmt_10@PAGE
    add x0, x0, Ltf_fmt_10@PAGEOFF
    adrp x1, Ltf_slots_10@PAGE
    add x1, x1, Ltf_slots_10@PAGEOFF
    mov x2, #10
    bl _sea_printf
    // case 11: %X of 255
    adrp x0, Ltf_fmt_11@PAGE
    add x0, x0, Ltf_fmt_11@PAGEOFF
    adrp x1, Ltf_slots_11@PAGE
    add x1, x1, Ltf_slots_11@PAGEOFF
    mov x2, #11
    bl _sea_printf
    // case 12: %X of -1
    adrp x0, Ltf_fmt_12@PAGE
    add x0, x0, Ltf_fmt_12@PAGEOFF
    adrp x1, Ltf_slots_12@PAGE
    add x1, x1, Ltf_slots_12@PAGEOFF
    mov x2, #12
    bl _sea_printf
    // case 13: %X of -9223372036854775808
    adrp x0, Ltf_fmt_13@PAGE
    add x0, x0, Ltf_fmt_13@PAGEOFF
    adrp x1, Ltf_slots_13@PAGE
    add x1, x1, Ltf_slots_13@PAGEOFF
    mov x2, #13
    bl _sea_printf
    // case 14: %X of 9223372036854775807
    adrp x0, Ltf_fmt_14@PAGE
    add x0, x0, Ltf_fmt_14@PAGEOFF
    adrp x1, Ltf_slots_14@PAGE
    add x1, x1, Ltf_slots_14@PAGEOFF
    mov x2, #14
    bl _sea_printf
    // case 15: %X of 3735928559
    adrp x0, Ltf_fmt_15@PAGE
    add x0, x0, Ltf_fmt_15@PAGEOFF
    adrp x1, Ltf_slots_15@PAGE
    add x1, x1, Ltf_slots_15@PAGEOFF
    mov x2, #15
    bl _sea_printf
    // case 16: %X of 16
    adrp x0, Ltf_fmt_16@PAGE
    add x0, x0, Ltf_fmt_16@PAGEOFF
    adrp x1, Ltf_slots_16@PAGE
    add x1, x1, Ltf_slots_16@PAGEOFF
    mov x2, #16
    bl _sea_printf
    // case 17: %X of 419385573
    adrp x0, Ltf_fmt_17@PAGE
    add x0, x0, Ltf_fmt_17@PAGEOFF
    adrp x1, Ltf_slots_17@PAGE
    add x1, x1, Ltf_slots_17@PAGEOFF
    mov x2, #17
    bl _sea_printf
    // case 18: %8x of 0
    adrp x0, Ltf_fmt_18@PAGE
    add x0, x0, Ltf_fmt_18@PAGEOFF
    adrp x1, Ltf_slots_18@PAGE
    add x1, x1, Ltf_slots_18@PAGEOFF
    mov x2, #18
    bl _sea_printf
    // case 19: %8x of 1
    adrp x0, Ltf_fmt_19@PAGE
    add x0, x0, Ltf_fmt_19@PAGEOFF
    adrp x1, Ltf_slots_19@PAGE
    add x1, x1, Ltf_slots_19@PAGEOFF
    mov x2, #19
    bl _sea_printf
    // case 20: %8x of 255
    adrp x0, Ltf_fmt_20@PAGE
    add x0, x0, Ltf_fmt_20@PAGEOFF
    adrp x1, Ltf_slots_20@PAGE
    add x1, x1, Ltf_slots_20@PAGEOFF
    mov x2, #20
    bl _sea_printf
    // case 21: %8x of -1
    adrp x0, Ltf_fmt_21@PAGE
    add x0, x0, Ltf_fmt_21@PAGEOFF
    adrp x1, Ltf_slots_21@PAGE
    add x1, x1, Ltf_slots_21@PAGEOFF
    mov x2, #21
    bl _sea_printf
    // case 22: %8x of -9223372036854775808
    adrp x0, Ltf_fmt_22@PAGE
    add x0, x0, Ltf_fmt_22@PAGEOFF
    adrp x1, Ltf_slots_22@PAGE
    add x1, x1, Ltf_slots_22@PAGEOFF
    mov x2, #22
    bl _sea_printf
    // case 23: %8x of 9223372036854775807
    adrp x0, Ltf_fmt_23@PAGE
    add x0, x0, Ltf_fmt_23@PAGEOFF
    adrp x1, Ltf_slots_23@PAGE
    add x1, x1, Ltf_slots_23@PAGEOFF
    mov x2, #23
    bl _sea_printf
    // case 24: %8x of 3735928559
    adrp x0, Ltf_fmt_24@PAGE
    add x0, x0, Ltf_fmt_24@PAGEOFF
    adrp x1, Ltf_slots_24@PAGE
    add x1, x1, Ltf_slots_24@PAGEOFF
    mov x2, #24
    bl _sea_printf
    // case 25: %8x of 16
    adrp x0, Ltf_fmt_25@PAGE
    add x0, x0, Ltf_fmt_25@PAGEOFF
    adrp x1, Ltf_slots_25@PAGE
    add x1, x1, Ltf_slots_25@PAGEOFF
    mov x2, #25
    bl _sea_printf
    // case 26: %8x of 419385573
    adrp x0, Ltf_fmt_26@PAGE
    add x0, x0, Ltf_fmt_26@PAGEOFF
    adrp x1, Ltf_slots_26@PAGE
    add x1, x1, Ltf_slots_26@PAGEOFF
    mov x2, #26
    bl _sea_printf
    // case 27: %-8x| of 0
    adrp x0, Ltf_fmt_27@PAGE
    add x0, x0, Ltf_fmt_27@PAGEOFF
    adrp x1, Ltf_slots_27@PAGE
    add x1, x1, Ltf_slots_27@PAGEOFF
    mov x2, #27
    bl _sea_printf
    // case 28: %-8x| of 1
    adrp x0, Ltf_fmt_28@PAGE
    add x0, x0, Ltf_fmt_28@PAGEOFF
    adrp x1, Ltf_slots_28@PAGE
    add x1, x1, Ltf_slots_28@PAGEOFF
    mov x2, #28
    bl _sea_printf
    // case 29: %-8x| of 255
    adrp x0, Ltf_fmt_29@PAGE
    add x0, x0, Ltf_fmt_29@PAGEOFF
    adrp x1, Ltf_slots_29@PAGE
    add x1, x1, Ltf_slots_29@PAGEOFF
    mov x2, #29
    bl _sea_printf
    // case 30: %-8x| of -1
    adrp x0, Ltf_fmt_30@PAGE
    add x0, x0, Ltf_fmt_30@PAGEOFF
    adrp x1, Ltf_slots_30@PAGE
    add x1, x1, Ltf_slots_30@PAGEOFF
    mov x2, #30
    bl _sea_printf
    // case 31: %-8x| of -9223372036854775808
    adrp x0, Ltf_fmt_31@PAGE
    add x0, x0, Ltf_fmt_31@PAGEOFF
    adrp x1, Ltf_slots_31@PAGE
    add x1, x1, Ltf_slots_31@PAGEOFF
    mov x2, #31
    bl _sea_printf
    // case 32: %-8x| of 9223372036854775807
    adrp x0, Ltf_fmt_32@PAGE
    add x0, x0, Ltf_fmt_32@PAGEOFF
    adrp x1, Ltf_slots_32@PAGE
    add x1, x1, Ltf_slots_32@PAGEOFF
    mov x2, #32
    bl _sea_printf
    // case 33: %-8x| of 3735928559
    adrp x0, Ltf_fmt_33@PAGE
    add x0, x0, Ltf_fmt_33@PAGEOFF
    adrp x1, Ltf_slots_33@PAGE
    add x1, x1, Ltf_slots_33@PAGEOFF
    mov x2, #33
    bl _sea_printf
    // case 34: %-8x| of 16
    adrp x0, Ltf_fmt_34@PAGE
    add x0, x0, Ltf_fmt_34@PAGEOFF
    adrp x1, Ltf_slots_34@PAGE
    add x1, x1, Ltf_slots_34@PAGEOFF
    mov x2, #34
    bl _sea_printf
    // case 35: %-8x| of 419385573
    adrp x0, Ltf_fmt_35@PAGE
    add x0, x0, Ltf_fmt_35@PAGEOFF
    adrp x1, Ltf_slots_35@PAGE
    add x1, x1, Ltf_slots_35@PAGEOFF
    mov x2, #35
    bl _sea_printf
    // case 36: %08x of 0
    adrp x0, Ltf_fmt_36@PAGE
    add x0, x0, Ltf_fmt_36@PAGEOFF
    adrp x1, Ltf_slots_36@PAGE
    add x1, x1, Ltf_slots_36@PAGEOFF
    mov x2, #36
    bl _sea_printf
    // case 37: %08x of 1
    adrp x0, Ltf_fmt_37@PAGE
    add x0, x0, Ltf_fmt_37@PAGEOFF
    adrp x1, Ltf_slots_37@PAGE
    add x1, x1, Ltf_slots_37@PAGEOFF
    mov x2, #37
    bl _sea_printf
    // case 38: %08x of 255
    adrp x0, Ltf_fmt_38@PAGE
    add x0, x0, Ltf_fmt_38@PAGEOFF
    adrp x1, Ltf_slots_38@PAGE
    add x1, x1, Ltf_slots_38@PAGEOFF
    mov x2, #38
    bl _sea_printf
    // case 39: %08x of -1
    adrp x0, Ltf_fmt_39@PAGE
    add x0, x0, Ltf_fmt_39@PAGEOFF
    adrp x1, Ltf_slots_39@PAGE
    add x1, x1, Ltf_slots_39@PAGEOFF
    mov x2, #39
    bl _sea_printf
    // case 40: %08x of -9223372036854775808
    adrp x0, Ltf_fmt_40@PAGE
    add x0, x0, Ltf_fmt_40@PAGEOFF
    adrp x1, Ltf_slots_40@PAGE
    add x1, x1, Ltf_slots_40@PAGEOFF
    mov x2, #40
    bl _sea_printf
    // case 41: %08x of 9223372036854775807
    adrp x0, Ltf_fmt_41@PAGE
    add x0, x0, Ltf_fmt_41@PAGEOFF
    adrp x1, Ltf_slots_41@PAGE
    add x1, x1, Ltf_slots_41@PAGEOFF
    mov x2, #41
    bl _sea_printf
    // case 42: %08x of 3735928559
    adrp x0, Ltf_fmt_42@PAGE
    add x0, x0, Ltf_fmt_42@PAGEOFF
    adrp x1, Ltf_slots_42@PAGE
    add x1, x1, Ltf_slots_42@PAGEOFF
    mov x2, #42
    bl _sea_printf
    // case 43: %08x of 16
    adrp x0, Ltf_fmt_43@PAGE
    add x0, x0, Ltf_fmt_43@PAGEOFF
    adrp x1, Ltf_slots_43@PAGE
    add x1, x1, Ltf_slots_43@PAGEOFF
    mov x2, #43
    bl _sea_printf
    // case 44: %08x of 419385573
    adrp x0, Ltf_fmt_44@PAGE
    add x0, x0, Ltf_fmt_44@PAGEOFF
    adrp x1, Ltf_slots_44@PAGE
    add x1, x1, Ltf_slots_44@PAGEOFF
    mov x2, #44
    bl _sea_printf
    // case 45: %#x of 0
    adrp x0, Ltf_fmt_45@PAGE
    add x0, x0, Ltf_fmt_45@PAGEOFF
    adrp x1, Ltf_slots_45@PAGE
    add x1, x1, Ltf_slots_45@PAGEOFF
    mov x2, #45
    bl _sea_printf
    // case 46: %#x of 1
    adrp x0, Ltf_fmt_46@PAGE
    add x0, x0, Ltf_fmt_46@PAGEOFF
    adrp x1, Ltf_slots_46@PAGE
    add x1, x1, Ltf_slots_46@PAGEOFF
    mov x2, #46
    bl _sea_printf
    // case 47: %#x of 255
    adrp x0, Ltf_fmt_47@PAGE
    add x0, x0, Ltf_fmt_47@PAGEOFF
    adrp x1, Ltf_slots_47@PAGE
    add x1, x1, Ltf_slots_47@PAGEOFF
    mov x2, #47
    bl _sea_printf
    // case 48: %#x of -1
    adrp x0, Ltf_fmt_48@PAGE
    add x0, x0, Ltf_fmt_48@PAGEOFF
    adrp x1, Ltf_slots_48@PAGE
    add x1, x1, Ltf_slots_48@PAGEOFF
    mov x2, #48
    bl _sea_printf
    // case 49: %#x of -9223372036854775808
    adrp x0, Ltf_fmt_49@PAGE
    add x0, x0, Ltf_fmt_49@PAGEOFF
    adrp x1, Ltf_slots_49@PAGE
    add x1, x1, Ltf_slots_49@PAGEOFF
    mov x2, #49
    bl _sea_printf
    // case 50: %#x of 9223372036854775807
    adrp x0, Ltf_fmt_50@PAGE
    add x0, x0, Ltf_fmt_50@PAGEOFF
    adrp x1, Ltf_slots_50@PAGE
    add x1, x1, Ltf_slots_50@PAGEOFF
    mov x2, #50
    bl _sea_printf
    // case 51: %#x of 3735928559
    adrp x0, Ltf_fmt_51@PAGE
    add x0, x0, Ltf_fmt_51@PAGEOFF
    adrp x1, Ltf_slots_51@PAGE
    add x1, x1, Ltf_slots_51@PAGEOFF
    mov x2, #51
    bl _sea_printf
    // case 52: %#x of 16
    adrp x0, Ltf_fmt_52@PAGE
    add x0, x0, Ltf_fmt_52@PAGEOFF
    adrp x1, Ltf_slots_52@PAGE
    add x1, x1, Ltf_slots_52@PAGEOFF
    mov x2, #52
    bl _sea_printf
    // case 53: %#x of 419385573
    adrp x0, Ltf_fmt_53@PAGE
    add x0, x0, Ltf_fmt_53@PAGEOFF
    adrp x1, Ltf_slots_53@PAGE
    add x1, x1, Ltf_slots_53@PAGEOFF
    mov x2, #53
    bl _sea_printf
    // case 54: %#X of 0
    adrp x0, Ltf_fmt_54@PAGE
    add x0, x0, Ltf_fmt_54@PAGEOFF
    adrp x1, Ltf_slots_54@PAGE
    add x1, x1, Ltf_slots_54@PAGEOFF
    mov x2, #54
    bl _sea_printf
    // case 55: %#X of 1
    adrp x0, Ltf_fmt_55@PAGE
    add x0, x0, Ltf_fmt_55@PAGEOFF
    adrp x1, Ltf_slots_55@PAGE
    add x1, x1, Ltf_slots_55@PAGEOFF
    mov x2, #55
    bl _sea_printf
    // case 56: %#X of 255
    adrp x0, Ltf_fmt_56@PAGE
    add x0, x0, Ltf_fmt_56@PAGEOFF
    adrp x1, Ltf_slots_56@PAGE
    add x1, x1, Ltf_slots_56@PAGEOFF
    mov x2, #56
    bl _sea_printf
    // case 57: %#X of -1
    adrp x0, Ltf_fmt_57@PAGE
    add x0, x0, Ltf_fmt_57@PAGEOFF
    adrp x1, Ltf_slots_57@PAGE
    add x1, x1, Ltf_slots_57@PAGEOFF
    mov x2, #57
    bl _sea_printf
    // case 58: %#X of -9223372036854775808
    adrp x0, Ltf_fmt_58@PAGE
    add x0, x0, Ltf_fmt_58@PAGEOFF
    adrp x1, Ltf_slots_58@PAGE
    add x1, x1, Ltf_slots_58@PAGEOFF
    mov x2, #58
    bl _sea_printf
    // case 59: %#X of 9223372036854775807
    adrp x0, Ltf_fmt_59@PAGE
    add x0, x0, Ltf_fmt_59@PAGEOFF
    adrp x1, Ltf_slots_59@PAGE
    add x1, x1, Ltf_slots_59@PAGEOFF
    mov x2, #59
    bl _sea_printf
    // case 60: %#X of 3735928559
    adrp x0, Ltf_fmt_60@PAGE
    add x0, x0, Ltf_fmt_60@PAGEOFF
    adrp x1, Ltf_slots_60@PAGE
    add x1, x1, Ltf_slots_60@PAGEOFF
    mov x2, #60
    bl _sea_printf
    // case 61: %#X of 16
    adrp x0, Ltf_fmt_61@PAGE
    add x0, x0, Ltf_fmt_61@PAGEOFF
    adrp x1, Ltf_slots_61@PAGE
    add x1, x1, Ltf_slots_61@PAGEOFF
    mov x2, #61
    bl _sea_printf
    // case 62: %#X of 419385573
    adrp x0, Ltf_fmt_62@PAGE
    add x0, x0, Ltf_fmt_62@PAGEOFF
    adrp x1, Ltf_slots_62@PAGE
    add x1, x1, Ltf_slots_62@PAGEOFF
    mov x2, #62
    bl _sea_printf
    // case 63: %#010x of 0
    adrp x0, Ltf_fmt_63@PAGE
    add x0, x0, Ltf_fmt_63@PAGEOFF
    adrp x1, Ltf_slots_63@PAGE
    add x1, x1, Ltf_slots_63@PAGEOFF
    mov x2, #63
    bl _sea_printf
    // case 64: %#010x of 1
    adrp x0, Ltf_fmt_64@PAGE
    add x0, x0, Ltf_fmt_64@PAGEOFF
    adrp x1, Ltf_slots_64@PAGE
    add x1, x1, Ltf_slots_64@PAGEOFF
    mov x2, #64
    bl _sea_printf
    // case 65: %#010x of 255
    adrp x0, Ltf_fmt_65@PAGE
    add x0, x0, Ltf_fmt_65@PAGEOFF
    adrp x1, Ltf_slots_65@PAGE
    add x1, x1, Ltf_slots_65@PAGEOFF
    mov x2, #65
    bl _sea_printf
    // case 66: %#010x of -1
    adrp x0, Ltf_fmt_66@PAGE
    add x0, x0, Ltf_fmt_66@PAGEOFF
    adrp x1, Ltf_slots_66@PAGE
    add x1, x1, Ltf_slots_66@PAGEOFF
    mov x2, #66
    bl _sea_printf
    // case 67: %#010x of -9223372036854775808
    adrp x0, Ltf_fmt_67@PAGE
    add x0, x0, Ltf_fmt_67@PAGEOFF
    adrp x1, Ltf_slots_67@PAGE
    add x1, x1, Ltf_slots_67@PAGEOFF
    mov x2, #67
    bl _sea_printf
    // case 68: %#010x of 9223372036854775807
    adrp x0, Ltf_fmt_68@PAGE
    add x0, x0, Ltf_fmt_68@PAGEOFF
    adrp x1, Ltf_slots_68@PAGE
    add x1, x1, Ltf_slots_68@PAGEOFF
    mov x2, #68
    bl _sea_printf
    // case 69: %#010x of 3735928559
    adrp x0, Ltf_fmt_69@PAGE
    add x0, x0, Ltf_fmt_69@PAGEOFF
    adrp x1, Ltf_slots_69@PAGE
    add x1, x1, Ltf_slots_69@PAGEOFF
    mov x2, #69
    bl _sea_printf
    // case 70: %#010x of 16
    adrp x0, Ltf_fmt_70@PAGE
    add x0, x0, Ltf_fmt_70@PAGEOFF
    adrp x1, Ltf_slots_70@PAGE
    add x1, x1, Ltf_slots_70@PAGEOFF
    mov x2, #70
    bl _sea_printf
    // case 71: %#010x of 419385573
    adrp x0, Ltf_fmt_71@PAGE
    add x0, x0, Ltf_fmt_71@PAGEOFF
    adrp x1, Ltf_slots_71@PAGE
    add x1, x1, Ltf_slots_71@PAGEOFF
    mov x2, #71
    bl _sea_printf
    // case 72: %#.4x of 0
    adrp x0, Ltf_fmt_72@PAGE
    add x0, x0, Ltf_fmt_72@PAGEOFF
    adrp x1, Ltf_slots_72@PAGE
    add x1, x1, Ltf_slots_72@PAGEOFF
    mov x2, #72
    bl _sea_printf
    // case 73: %#.4x of 1
    adrp x0, Ltf_fmt_73@PAGE
    add x0, x0, Ltf_fmt_73@PAGEOFF
    adrp x1, Ltf_slots_73@PAGE
    add x1, x1, Ltf_slots_73@PAGEOFF
    mov x2, #73
    bl _sea_printf
    // case 74: %#.4x of 255
    adrp x0, Ltf_fmt_74@PAGE
    add x0, x0, Ltf_fmt_74@PAGEOFF
    adrp x1, Ltf_slots_74@PAGE
    add x1, x1, Ltf_slots_74@PAGEOFF
    mov x2, #74
    bl _sea_printf
    // case 75: %#.4x of -1
    adrp x0, Ltf_fmt_75@PAGE
    add x0, x0, Ltf_fmt_75@PAGEOFF
    adrp x1, Ltf_slots_75@PAGE
    add x1, x1, Ltf_slots_75@PAGEOFF
    mov x2, #75
    bl _sea_printf
    // case 76: %#.4x of -9223372036854775808
    adrp x0, Ltf_fmt_76@PAGE
    add x0, x0, Ltf_fmt_76@PAGEOFF
    adrp x1, Ltf_slots_76@PAGE
    add x1, x1, Ltf_slots_76@PAGEOFF
    mov x2, #76
    bl _sea_printf
    // case 77: %#.4x of 9223372036854775807
    adrp x0, Ltf_fmt_77@PAGE
    add x0, x0, Ltf_fmt_77@PAGEOFF
    adrp x1, Ltf_slots_77@PAGE
    add x1, x1, Ltf_slots_77@PAGEOFF
    mov x2, #77
    bl _sea_printf
    // case 78: %#.4x of 3735928559
    adrp x0, Ltf_fmt_78@PAGE
    add x0, x0, Ltf_fmt_78@PAGEOFF
    adrp x1, Ltf_slots_78@PAGE
    add x1, x1, Ltf_slots_78@PAGEOFF
    mov x2, #78
    bl _sea_printf
    // case 79: %#.4x of 16
    adrp x0, Ltf_fmt_79@PAGE
    add x0, x0, Ltf_fmt_79@PAGEOFF
    adrp x1, Ltf_slots_79@PAGE
    add x1, x1, Ltf_slots_79@PAGEOFF
    mov x2, #79
    bl _sea_printf
    // case 80: %#.4x of 419385573
    adrp x0, Ltf_fmt_80@PAGE
    add x0, x0, Ltf_fmt_80@PAGEOFF
    adrp x1, Ltf_slots_80@PAGE
    add x1, x1, Ltf_slots_80@PAGEOFF
    mov x2, #80
    bl _sea_printf
    // case 81: %.0x of 0
    adrp x0, Ltf_fmt_81@PAGE
    add x0, x0, Ltf_fmt_81@PAGEOFF
    adrp x1, Ltf_slots_81@PAGE
    add x1, x1, Ltf_slots_81@PAGEOFF
    mov x2, #81
    bl _sea_printf
    // case 82: %.0x of 1
    adrp x0, Ltf_fmt_82@PAGE
    add x0, x0, Ltf_fmt_82@PAGEOFF
    adrp x1, Ltf_slots_82@PAGE
    add x1, x1, Ltf_slots_82@PAGEOFF
    mov x2, #82
    bl _sea_printf
    // case 83: %.0x of 255
    adrp x0, Ltf_fmt_83@PAGE
    add x0, x0, Ltf_fmt_83@PAGEOFF
    adrp x1, Ltf_slots_83@PAGE
    add x1, x1, Ltf_slots_83@PAGEOFF
    mov x2, #83
    bl _sea_printf
    // case 84: %.0x of -1
    adrp x0, Ltf_fmt_84@PAGE
    add x0, x0, Ltf_fmt_84@PAGEOFF
    adrp x1, Ltf_slots_84@PAGE
    add x1, x1, Ltf_slots_84@PAGEOFF
    mov x2, #84
    bl _sea_printf
    // case 85: %.0x of -9223372036854775808
    adrp x0, Ltf_fmt_85@PAGE
    add x0, x0, Ltf_fmt_85@PAGEOFF
    adrp x1, Ltf_slots_85@PAGE
    add x1, x1, Ltf_slots_85@PAGEOFF
    mov x2, #85
    bl _sea_printf
    // case 86: %.0x of 9223372036854775807
    adrp x0, Ltf_fmt_86@PAGE
    add x0, x0, Ltf_fmt_86@PAGEOFF
    adrp x1, Ltf_slots_86@PAGE
    add x1, x1, Ltf_slots_86@PAGEOFF
    mov x2, #86
    bl _sea_printf
    // case 87: %.0x of 3735928559
    adrp x0, Ltf_fmt_87@PAGE
    add x0, x0, Ltf_fmt_87@PAGEOFF
    adrp x1, Ltf_slots_87@PAGE
    add x1, x1, Ltf_slots_87@PAGEOFF
    mov x2, #87
    bl _sea_printf
    // case 88: %.0x of 16
    adrp x0, Ltf_fmt_88@PAGE
    add x0, x0, Ltf_fmt_88@PAGEOFF
    adrp x1, Ltf_slots_88@PAGE
    add x1, x1, Ltf_slots_88@PAGEOFF
    mov x2, #88
    bl _sea_printf
    // case 89: %.0x of 419385573
    adrp x0, Ltf_fmt_89@PAGE
    add x0, x0, Ltf_fmt_89@PAGEOFF
    adrp x1, Ltf_slots_89@PAGE
    add x1, x1, Ltf_slots_89@PAGEOFF
    mov x2, #89
    bl _sea_printf
    // case 90: %#.0x of 0
    adrp x0, Ltf_fmt_90@PAGE
    add x0, x0, Ltf_fmt_90@PAGEOFF
    adrp x1, Ltf_slots_90@PAGE
    add x1, x1, Ltf_slots_90@PAGEOFF
    mov x2, #90
    bl _sea_printf
    // case 91: %#.0x of 1
    adrp x0, Ltf_fmt_91@PAGE
    add x0, x0, Ltf_fmt_91@PAGEOFF
    adrp x1, Ltf_slots_91@PAGE
    add x1, x1, Ltf_slots_91@PAGEOFF
    mov x2, #91
    bl _sea_printf
    // case 92: %#.0x of 255
    adrp x0, Ltf_fmt_92@PAGE
    add x0, x0, Ltf_fmt_92@PAGEOFF
    adrp x1, Ltf_slots_92@PAGE
    add x1, x1, Ltf_slots_92@PAGEOFF
    mov x2, #92
    bl _sea_printf
    // case 93: %#.0x of -1
    adrp x0, Ltf_fmt_93@PAGE
    add x0, x0, Ltf_fmt_93@PAGEOFF
    adrp x1, Ltf_slots_93@PAGE
    add x1, x1, Ltf_slots_93@PAGEOFF
    mov x2, #93
    bl _sea_printf
    // case 94: %#.0x of -9223372036854775808
    adrp x0, Ltf_fmt_94@PAGE
    add x0, x0, Ltf_fmt_94@PAGEOFF
    adrp x1, Ltf_slots_94@PAGE
    add x1, x1, Ltf_slots_94@PAGEOFF
    mov x2, #94
    bl _sea_printf
    // case 95: %#.0x of 9223372036854775807
    adrp x0, Ltf_fmt_95@PAGE
    add x0, x0, Ltf_fmt_95@PAGEOFF
    adrp x1, Ltf_slots_95@PAGE
    add x1, x1, Ltf_slots_95@PAGEOFF
    mov x2, #95
    bl _sea_printf
    // case 96: %#.0x of 3735928559
    adrp x0, Ltf_fmt_96@PAGE
    add x0, x0, Ltf_fmt_96@PAGEOFF
    adrp x1, Ltf_slots_96@PAGE
    add x1, x1, Ltf_slots_96@PAGEOFF
    mov x2, #96
    bl _sea_printf
    // case 97: %#.0x of 16
    adrp x0, Ltf_fmt_97@PAGE
    add x0, x0, Ltf_fmt_97@PAGEOFF
    adrp x1, Ltf_slots_97@PAGE
    add x1, x1, Ltf_slots_97@PAGEOFF
    mov x2, #97
    bl _sea_printf
    // case 98: %#.0x of 419385573
    adrp x0, Ltf_fmt_98@PAGE
    add x0, x0, Ltf_fmt_98@PAGEOFF
    adrp x1, Ltf_slots_98@PAGE
    add x1, x1, Ltf_slots_98@PAGEOFF
    mov x2, #98
    bl _sea_printf
    // case 99: %.3x of 0
    adrp x0, Ltf_fmt_99@PAGE
    add x0, x0, Ltf_fmt_99@PAGEOFF
    adrp x1, Ltf_slots_99@PAGE
    add x1, x1, Ltf_slots_99@PAGEOFF
    mov x2, #99
    bl _sea_printf
    // case 100: %.3x of 1
    adrp x0, Ltf_fmt_100@PAGE
    add x0, x0, Ltf_fmt_100@PAGEOFF
    adrp x1, Ltf_slots_100@PAGE
    add x1, x1, Ltf_slots_100@PAGEOFF
    mov x2, #100
    bl _sea_printf
    // case 101: %.3x of 255
    adrp x0, Ltf_fmt_101@PAGE
    add x0, x0, Ltf_fmt_101@PAGEOFF
    adrp x1, Ltf_slots_101@PAGE
    add x1, x1, Ltf_slots_101@PAGEOFF
    mov x2, #101
    bl _sea_printf
    // case 102: %.3x of -1
    adrp x0, Ltf_fmt_102@PAGE
    add x0, x0, Ltf_fmt_102@PAGEOFF
    adrp x1, Ltf_slots_102@PAGE
    add x1, x1, Ltf_slots_102@PAGEOFF
    mov x2, #102
    bl _sea_printf
    // case 103: %.3x of -9223372036854775808
    adrp x0, Ltf_fmt_103@PAGE
    add x0, x0, Ltf_fmt_103@PAGEOFF
    adrp x1, Ltf_slots_103@PAGE
    add x1, x1, Ltf_slots_103@PAGEOFF
    mov x2, #103
    bl _sea_printf
    // case 104: %.3x of 9223372036854775807
    adrp x0, Ltf_fmt_104@PAGE
    add x0, x0, Ltf_fmt_104@PAGEOFF
    adrp x1, Ltf_slots_104@PAGE
    add x1, x1, Ltf_slots_104@PAGEOFF
    mov x2, #104
    bl _sea_printf
    // case 105: %.3x of 3735928559
    adrp x0, Ltf_fmt_105@PAGE
    add x0, x0, Ltf_fmt_105@PAGEOFF
    adrp x1, Ltf_slots_105@PAGE
    add x1, x1, Ltf_slots_105@PAGEOFF
    mov x2, #105
    bl _sea_printf
    // case 106: %.3x of 16
    adrp x0, Ltf_fmt_106@PAGE
    add x0, x0, Ltf_fmt_106@PAGEOFF
    adrp x1, Ltf_slots_106@PAGE
    add x1, x1, Ltf_slots_106@PAGEOFF
    mov x2, #106
    bl _sea_printf
    // case 107: %.3x of 419385573
    adrp x0, Ltf_fmt_107@PAGE
    add x0, x0, Ltf_fmt_107@PAGEOFF
    adrp x1, Ltf_slots_107@PAGE
    add x1, x1, Ltf_slots_107@PAGEOFF
    mov x2, #107
    bl _sea_printf
    // case 108: %8.3x of 0
    adrp x0, Ltf_fmt_108@PAGE
    add x0, x0, Ltf_fmt_108@PAGEOFF
    adrp x1, Ltf_slots_108@PAGE
    add x1, x1, Ltf_slots_108@PAGEOFF
    mov x2, #108
    bl _sea_printf
    // case 109: %8.3x of 1
    adrp x0, Ltf_fmt_109@PAGE
    add x0, x0, Ltf_fmt_109@PAGEOFF
    adrp x1, Ltf_slots_109@PAGE
    add x1, x1, Ltf_slots_109@PAGEOFF
    mov x2, #109
    bl _sea_printf
    // case 110: %8.3x of 255
    adrp x0, Ltf_fmt_110@PAGE
    add x0, x0, Ltf_fmt_110@PAGEOFF
    adrp x1, Ltf_slots_110@PAGE
    add x1, x1, Ltf_slots_110@PAGEOFF
    mov x2, #110
    bl _sea_printf
    // case 111: %8.3x of -1
    adrp x0, Ltf_fmt_111@PAGE
    add x0, x0, Ltf_fmt_111@PAGEOFF
    adrp x1, Ltf_slots_111@PAGE
    add x1, x1, Ltf_slots_111@PAGEOFF
    mov x2, #111
    bl _sea_printf
    // case 112: %8.3x of -9223372036854775808
    adrp x0, Ltf_fmt_112@PAGE
    add x0, x0, Ltf_fmt_112@PAGEOFF
    adrp x1, Ltf_slots_112@PAGE
    add x1, x1, Ltf_slots_112@PAGEOFF
    mov x2, #112
    bl _sea_printf
    // case 113: %8.3x of 9223372036854775807
    adrp x0, Ltf_fmt_113@PAGE
    add x0, x0, Ltf_fmt_113@PAGEOFF
    adrp x1, Ltf_slots_113@PAGE
    add x1, x1, Ltf_slots_113@PAGEOFF
    mov x2, #113
    bl _sea_printf
    // case 114: %8.3x of 3735928559
    adrp x0, Ltf_fmt_114@PAGE
    add x0, x0, Ltf_fmt_114@PAGEOFF
    adrp x1, Ltf_slots_114@PAGE
    add x1, x1, Ltf_slots_114@PAGEOFF
    mov x2, #114
    bl _sea_printf
    // case 115: %8.3x of 16
    adrp x0, Ltf_fmt_115@PAGE
    add x0, x0, Ltf_fmt_115@PAGEOFF
    adrp x1, Ltf_slots_115@PAGE
    add x1, x1, Ltf_slots_115@PAGEOFF
    mov x2, #115
    bl _sea_printf
    // case 116: %8.3x of 419385573
    adrp x0, Ltf_fmt_116@PAGE
    add x0, x0, Ltf_fmt_116@PAGEOFF
    adrp x1, Ltf_slots_116@PAGE
    add x1, x1, Ltf_slots_116@PAGEOFF
    mov x2, #116
    bl _sea_printf
    // case 117: %-8.3x| of 0
    adrp x0, Ltf_fmt_117@PAGE
    add x0, x0, Ltf_fmt_117@PAGEOFF
    adrp x1, Ltf_slots_117@PAGE
    add x1, x1, Ltf_slots_117@PAGEOFF
    mov x2, #117
    bl _sea_printf
    // case 118: %-8.3x| of 1
    adrp x0, Ltf_fmt_118@PAGE
    add x0, x0, Ltf_fmt_118@PAGEOFF
    adrp x1, Ltf_slots_118@PAGE
    add x1, x1, Ltf_slots_118@PAGEOFF
    mov x2, #118
    bl _sea_printf
    // case 119: %-8.3x| of 255
    adrp x0, Ltf_fmt_119@PAGE
    add x0, x0, Ltf_fmt_119@PAGEOFF
    adrp x1, Ltf_slots_119@PAGE
    add x1, x1, Ltf_slots_119@PAGEOFF
    mov x2, #119
    bl _sea_printf
    // case 120: %-8.3x| of -1
    adrp x0, Ltf_fmt_120@PAGE
    add x0, x0, Ltf_fmt_120@PAGEOFF
    adrp x1, Ltf_slots_120@PAGE
    add x1, x1, Ltf_slots_120@PAGEOFF
    mov x2, #120
    bl _sea_printf
    // case 121: %-8.3x| of -9223372036854775808
    adrp x0, Ltf_fmt_121@PAGE
    add x0, x0, Ltf_fmt_121@PAGEOFF
    adrp x1, Ltf_slots_121@PAGE
    add x1, x1, Ltf_slots_121@PAGEOFF
    mov x2, #121
    bl _sea_printf
    // case 122: %-8.3x| of 9223372036854775807
    adrp x0, Ltf_fmt_122@PAGE
    add x0, x0, Ltf_fmt_122@PAGEOFF
    adrp x1, Ltf_slots_122@PAGE
    add x1, x1, Ltf_slots_122@PAGEOFF
    mov x2, #122
    bl _sea_printf
    // case 123: %-8.3x| of 3735928559
    adrp x0, Ltf_fmt_123@PAGE
    add x0, x0, Ltf_fmt_123@PAGEOFF
    adrp x1, Ltf_slots_123@PAGE
    add x1, x1, Ltf_slots_123@PAGEOFF
    mov x2, #123
    bl _sea_printf
    // case 124: %-8.3x| of 16
    adrp x0, Ltf_fmt_124@PAGE
    add x0, x0, Ltf_fmt_124@PAGEOFF
    adrp x1, Ltf_slots_124@PAGE
    add x1, x1, Ltf_slots_124@PAGEOFF
    mov x2, #124
    bl _sea_printf
    // case 125: %-8.3x| of 419385573
    adrp x0, Ltf_fmt_125@PAGE
    add x0, x0, Ltf_fmt_125@PAGEOFF
    adrp x1, Ltf_slots_125@PAGE
    add x1, x1, Ltf_slots_125@PAGEOFF
    mov x2, #125
    bl _sea_printf
    // case 126: %08.3x of 0
    adrp x0, Ltf_fmt_126@PAGE
    add x0, x0, Ltf_fmt_126@PAGEOFF
    adrp x1, Ltf_slots_126@PAGE
    add x1, x1, Ltf_slots_126@PAGEOFF
    mov x2, #126
    bl _sea_printf
    // case 127: %08.3x of 1
    adrp x0, Ltf_fmt_127@PAGE
    add x0, x0, Ltf_fmt_127@PAGEOFF
    adrp x1, Ltf_slots_127@PAGE
    add x1, x1, Ltf_slots_127@PAGEOFF
    mov x2, #127
    bl _sea_printf
    // case 128: %08.3x of 255
    adrp x0, Ltf_fmt_128@PAGE
    add x0, x0, Ltf_fmt_128@PAGEOFF
    adrp x1, Ltf_slots_128@PAGE
    add x1, x1, Ltf_slots_128@PAGEOFF
    mov x2, #128
    bl _sea_printf
    // case 129: %08.3x of -1
    adrp x0, Ltf_fmt_129@PAGE
    add x0, x0, Ltf_fmt_129@PAGEOFF
    adrp x1, Ltf_slots_129@PAGE
    add x1, x1, Ltf_slots_129@PAGEOFF
    mov x2, #129
    bl _sea_printf
    // case 130: %08.3x of -9223372036854775808
    adrp x0, Ltf_fmt_130@PAGE
    add x0, x0, Ltf_fmt_130@PAGEOFF
    adrp x1, Ltf_slots_130@PAGE
    add x1, x1, Ltf_slots_130@PAGEOFF
    mov x2, #130
    bl _sea_printf
    // case 131: %08.3x of 9223372036854775807
    adrp x0, Ltf_fmt_131@PAGE
    add x0, x0, Ltf_fmt_131@PAGEOFF
    adrp x1, Ltf_slots_131@PAGE
    add x1, x1, Ltf_slots_131@PAGEOFF
    mov x2, #131
    bl _sea_printf
    // case 132: %08.3x of 3735928559
    adrp x0, Ltf_fmt_132@PAGE
    add x0, x0, Ltf_fmt_132@PAGEOFF
    adrp x1, Ltf_slots_132@PAGE
    add x1, x1, Ltf_slots_132@PAGEOFF
    mov x2, #132
    bl _sea_printf
    // case 133: %08.3x of 16
    adrp x0, Ltf_fmt_133@PAGE
    add x0, x0, Ltf_fmt_133@PAGEOFF
    adrp x1, Ltf_slots_133@PAGE
    add x1, x1, Ltf_slots_133@PAGEOFF
    mov x2, #133
    bl _sea_printf
    // case 134: %08.3x of 419385573
    adrp x0, Ltf_fmt_134@PAGE
    add x0, x0, Ltf_fmt_134@PAGEOFF
    adrp x1, Ltf_slots_134@PAGE
    add x1, x1, Ltf_slots_134@PAGEOFF
    mov x2, #134
    bl _sea_printf
    // case 135: %#8x of 0
    adrp x0, Ltf_fmt_135@PAGE
    add x0, x0, Ltf_fmt_135@PAGEOFF
    adrp x1, Ltf_slots_135@PAGE
    add x1, x1, Ltf_slots_135@PAGEOFF
    mov x2, #135
    bl _sea_printf
    // case 136: %#8x of 1
    adrp x0, Ltf_fmt_136@PAGE
    add x0, x0, Ltf_fmt_136@PAGEOFF
    adrp x1, Ltf_slots_136@PAGE
    add x1, x1, Ltf_slots_136@PAGEOFF
    mov x2, #136
    bl _sea_printf
    // case 137: %#8x of 255
    adrp x0, Ltf_fmt_137@PAGE
    add x0, x0, Ltf_fmt_137@PAGEOFF
    adrp x1, Ltf_slots_137@PAGE
    add x1, x1, Ltf_slots_137@PAGEOFF
    mov x2, #137
    bl _sea_printf
    // case 138: %#8x of -1
    adrp x0, Ltf_fmt_138@PAGE
    add x0, x0, Ltf_fmt_138@PAGEOFF
    adrp x1, Ltf_slots_138@PAGE
    add x1, x1, Ltf_slots_138@PAGEOFF
    mov x2, #138
    bl _sea_printf
    // case 139: %#8x of -9223372036854775808
    adrp x0, Ltf_fmt_139@PAGE
    add x0, x0, Ltf_fmt_139@PAGEOFF
    adrp x1, Ltf_slots_139@PAGE
    add x1, x1, Ltf_slots_139@PAGEOFF
    mov x2, #139
    bl _sea_printf
    // case 140: %#8x of 9223372036854775807
    adrp x0, Ltf_fmt_140@PAGE
    add x0, x0, Ltf_fmt_140@PAGEOFF
    adrp x1, Ltf_slots_140@PAGE
    add x1, x1, Ltf_slots_140@PAGEOFF
    mov x2, #140
    bl _sea_printf
    // case 141: %#8x of 3735928559
    adrp x0, Ltf_fmt_141@PAGE
    add x0, x0, Ltf_fmt_141@PAGEOFF
    adrp x1, Ltf_slots_141@PAGE
    add x1, x1, Ltf_slots_141@PAGEOFF
    mov x2, #141
    bl _sea_printf
    // case 142: %#8x of 16
    adrp x0, Ltf_fmt_142@PAGE
    add x0, x0, Ltf_fmt_142@PAGEOFF
    adrp x1, Ltf_slots_142@PAGE
    add x1, x1, Ltf_slots_142@PAGEOFF
    mov x2, #142
    bl _sea_printf
    // case 143: %#8x of 419385573
    adrp x0, Ltf_fmt_143@PAGE
    add x0, x0, Ltf_fmt_143@PAGEOFF
    adrp x1, Ltf_slots_143@PAGE
    add x1, x1, Ltf_slots_143@PAGEOFF
    mov x2, #143
    bl _sea_printf
    // case 144: %-#8x| of 0
    adrp x0, Ltf_fmt_144@PAGE
    add x0, x0, Ltf_fmt_144@PAGEOFF
    adrp x1, Ltf_slots_144@PAGE
    add x1, x1, Ltf_slots_144@PAGEOFF
    mov x2, #144
    bl _sea_printf
    // case 145: %-#8x| of 1
    adrp x0, Ltf_fmt_145@PAGE
    add x0, x0, Ltf_fmt_145@PAGEOFF
    adrp x1, Ltf_slots_145@PAGE
    add x1, x1, Ltf_slots_145@PAGEOFF
    mov x2, #145
    bl _sea_printf
    // case 146: %-#8x| of 255
    adrp x0, Ltf_fmt_146@PAGE
    add x0, x0, Ltf_fmt_146@PAGEOFF
    adrp x1, Ltf_slots_146@PAGE
    add x1, x1, Ltf_slots_146@PAGEOFF
    mov x2, #146
    bl _sea_printf
    // case 147: %-#8x| of -1
    adrp x0, Ltf_fmt_147@PAGE
    add x0, x0, Ltf_fmt_147@PAGEOFF
    adrp x1, Ltf_slots_147@PAGE
    add x1, x1, Ltf_slots_147@PAGEOFF
    mov x2, #147
    bl _sea_printf
    // case 148: %-#8x| of -9223372036854775808
    adrp x0, Ltf_fmt_148@PAGE
    add x0, x0, Ltf_fmt_148@PAGEOFF
    adrp x1, Ltf_slots_148@PAGE
    add x1, x1, Ltf_slots_148@PAGEOFF
    mov x2, #148
    bl _sea_printf
    // case 149: %-#8x| of 9223372036854775807
    adrp x0, Ltf_fmt_149@PAGE
    add x0, x0, Ltf_fmt_149@PAGEOFF
    adrp x1, Ltf_slots_149@PAGE
    add x1, x1, Ltf_slots_149@PAGEOFF
    mov x2, #149
    bl _sea_printf
    // case 150: %-#8x| of 3735928559
    adrp x0, Ltf_fmt_150@PAGE
    add x0, x0, Ltf_fmt_150@PAGEOFF
    adrp x1, Ltf_slots_150@PAGE
    add x1, x1, Ltf_slots_150@PAGEOFF
    mov x2, #150
    bl _sea_printf
    // case 151: %-#8x| of 16
    adrp x0, Ltf_fmt_151@PAGE
    add x0, x0, Ltf_fmt_151@PAGEOFF
    adrp x1, Ltf_slots_151@PAGE
    add x1, x1, Ltf_slots_151@PAGEOFF
    mov x2, #151
    bl _sea_printf
    // case 152: %-#8x| of 419385573
    adrp x0, Ltf_fmt_152@PAGE
    add x0, x0, Ltf_fmt_152@PAGEOFF
    adrp x1, Ltf_slots_152@PAGE
    add x1, x1, Ltf_slots_152@PAGEOFF
    mov x2, #152
    bl _sea_printf
    // case 153: %#08x of 0
    adrp x0, Ltf_fmt_153@PAGE
    add x0, x0, Ltf_fmt_153@PAGEOFF
    adrp x1, Ltf_slots_153@PAGE
    add x1, x1, Ltf_slots_153@PAGEOFF
    mov x2, #153
    bl _sea_printf
    // case 154: %#08x of 1
    adrp x0, Ltf_fmt_154@PAGE
    add x0, x0, Ltf_fmt_154@PAGEOFF
    adrp x1, Ltf_slots_154@PAGE
    add x1, x1, Ltf_slots_154@PAGEOFF
    mov x2, #154
    bl _sea_printf
    // case 155: %#08x of 255
    adrp x0, Ltf_fmt_155@PAGE
    add x0, x0, Ltf_fmt_155@PAGEOFF
    adrp x1, Ltf_slots_155@PAGE
    add x1, x1, Ltf_slots_155@PAGEOFF
    mov x2, #155
    bl _sea_printf
    // case 156: %#08x of -1
    adrp x0, Ltf_fmt_156@PAGE
    add x0, x0, Ltf_fmt_156@PAGEOFF
    adrp x1, Ltf_slots_156@PAGE
    add x1, x1, Ltf_slots_156@PAGEOFF
    mov x2, #156
    bl _sea_printf
    // case 157: %#08x of -9223372036854775808
    adrp x0, Ltf_fmt_157@PAGE
    add x0, x0, Ltf_fmt_157@PAGEOFF
    adrp x1, Ltf_slots_157@PAGE
    add x1, x1, Ltf_slots_157@PAGEOFF
    mov x2, #157
    bl _sea_printf
    // case 158: %#08x of 9223372036854775807
    adrp x0, Ltf_fmt_158@PAGE
    add x0, x0, Ltf_fmt_158@PAGEOFF
    adrp x1, Ltf_slots_158@PAGE
    add x1, x1, Ltf_slots_158@PAGEOFF
    mov x2, #158
    bl _sea_printf
    // case 159: %#08x of 3735928559
    adrp x0, Ltf_fmt_159@PAGE
    add x0, x0, Ltf_fmt_159@PAGEOFF
    adrp x1, Ltf_slots_159@PAGE
    add x1, x1, Ltf_slots_159@PAGEOFF
    mov x2, #159
    bl _sea_printf
    // case 160: %#08x of 16
    adrp x0, Ltf_fmt_160@PAGE
    add x0, x0, Ltf_fmt_160@PAGEOFF
    adrp x1, Ltf_slots_160@PAGE
    add x1, x1, Ltf_slots_160@PAGEOFF
    mov x2, #160
    bl _sea_printf
    // case 161: %#08x of 419385573
    adrp x0, Ltf_fmt_161@PAGE
    add x0, x0, Ltf_fmt_161@PAGEOFF
    adrp x1, Ltf_slots_161@PAGE
    add x1, x1, Ltf_slots_161@PAGEOFF
    mov x2, #161
    bl _sea_printf
    // case 162: %#12.4X of 0
    adrp x0, Ltf_fmt_162@PAGE
    add x0, x0, Ltf_fmt_162@PAGEOFF
    adrp x1, Ltf_slots_162@PAGE
    add x1, x1, Ltf_slots_162@PAGEOFF
    mov x2, #162
    bl _sea_printf
    // case 163: %#12.4X of 1
    adrp x0, Ltf_fmt_163@PAGE
    add x0, x0, Ltf_fmt_163@PAGEOFF
    adrp x1, Ltf_slots_163@PAGE
    add x1, x1, Ltf_slots_163@PAGEOFF
    mov x2, #163
    bl _sea_printf
    // case 164: %#12.4X of 255
    adrp x0, Ltf_fmt_164@PAGE
    add x0, x0, Ltf_fmt_164@PAGEOFF
    adrp x1, Ltf_slots_164@PAGE
    add x1, x1, Ltf_slots_164@PAGEOFF
    mov x2, #164
    bl _sea_printf
    // case 165: %#12.4X of -1
    adrp x0, Ltf_fmt_165@PAGE
    add x0, x0, Ltf_fmt_165@PAGEOFF
    adrp x1, Ltf_slots_165@PAGE
    add x1, x1, Ltf_slots_165@PAGEOFF
    mov x2, #165
    bl _sea_printf
    // case 166: %#12.4X of -9223372036854775808
    adrp x0, Ltf_fmt_166@PAGE
    add x0, x0, Ltf_fmt_166@PAGEOFF
    adrp x1, Ltf_slots_166@PAGE
    add x1, x1, Ltf_slots_166@PAGEOFF
    mov x2, #166
    bl _sea_printf
    // case 167: %#12.4X of 9223372036854775807
    adrp x0, Ltf_fmt_167@PAGE
    add x0, x0, Ltf_fmt_167@PAGEOFF
    adrp x1, Ltf_slots_167@PAGE
    add x1, x1, Ltf_slots_167@PAGEOFF
    mov x2, #167
    bl _sea_printf
    // case 168: %#12.4X of 3735928559
    adrp x0, Ltf_fmt_168@PAGE
    add x0, x0, Ltf_fmt_168@PAGEOFF
    adrp x1, Ltf_slots_168@PAGE
    add x1, x1, Ltf_slots_168@PAGEOFF
    mov x2, #168
    bl _sea_printf
    // case 169: %#12.4X of 16
    adrp x0, Ltf_fmt_169@PAGE
    add x0, x0, Ltf_fmt_169@PAGEOFF
    adrp x1, Ltf_slots_169@PAGE
    add x1, x1, Ltf_slots_169@PAGEOFF
    mov x2, #169
    bl _sea_printf
    // case 170: %#12.4X of 419385573
    adrp x0, Ltf_fmt_170@PAGE
    add x0, x0, Ltf_fmt_170@PAGEOFF
    adrp x1, Ltf_slots_170@PAGE
    add x1, x1, Ltf_slots_170@PAGEOFF
    mov x2, #170
    bl _sea_printf
    // case 171: %+x of 0
    adrp x0, Ltf_fmt_171@PAGE
    add x0, x0, Ltf_fmt_171@PAGEOFF
    adrp x1, Ltf_slots_171@PAGE
    add x1, x1, Ltf_slots_171@PAGEOFF
    mov x2, #171
    bl _sea_printf
    // case 172: %+x of 1
    adrp x0, Ltf_fmt_172@PAGE
    add x0, x0, Ltf_fmt_172@PAGEOFF
    adrp x1, Ltf_slots_172@PAGE
    add x1, x1, Ltf_slots_172@PAGEOFF
    mov x2, #172
    bl _sea_printf
    // case 173: %+x of 255
    adrp x0, Ltf_fmt_173@PAGE
    add x0, x0, Ltf_fmt_173@PAGEOFF
    adrp x1, Ltf_slots_173@PAGE
    add x1, x1, Ltf_slots_173@PAGEOFF
    mov x2, #173
    bl _sea_printf
    // case 174: %+x of -1
    adrp x0, Ltf_fmt_174@PAGE
    add x0, x0, Ltf_fmt_174@PAGEOFF
    adrp x1, Ltf_slots_174@PAGE
    add x1, x1, Ltf_slots_174@PAGEOFF
    mov x2, #174
    bl _sea_printf
    // case 175: %+x of -9223372036854775808
    adrp x0, Ltf_fmt_175@PAGE
    add x0, x0, Ltf_fmt_175@PAGEOFF
    adrp x1, Ltf_slots_175@PAGE
    add x1, x1, Ltf_slots_175@PAGEOFF
    mov x2, #175
    bl _sea_printf
    // case 176: %+x of 9223372036854775807
    adrp x0, Ltf_fmt_176@PAGE
    add x0, x0, Ltf_fmt_176@PAGEOFF
    adrp x1, Ltf_slots_176@PAGE
    add x1, x1, Ltf_slots_176@PAGEOFF
    mov x2, #176
    bl _sea_printf
    // case 177: %+x of 3735928559
    adrp x0, Ltf_fmt_177@PAGE
    add x0, x0, Ltf_fmt_177@PAGEOFF
    adrp x1, Ltf_slots_177@PAGE
    add x1, x1, Ltf_slots_177@PAGEOFF
    mov x2, #177
    bl _sea_printf
    // case 178: %+x of 16
    adrp x0, Ltf_fmt_178@PAGE
    add x0, x0, Ltf_fmt_178@PAGEOFF
    adrp x1, Ltf_slots_178@PAGE
    add x1, x1, Ltf_slots_178@PAGEOFF
    mov x2, #178
    bl _sea_printf
    // case 179: %+x of 419385573
    adrp x0, Ltf_fmt_179@PAGE
    add x0, x0, Ltf_fmt_179@PAGEOFF
    adrp x1, Ltf_slots_179@PAGE
    add x1, x1, Ltf_slots_179@PAGEOFF
    mov x2, #179
    bl _sea_printf
    // case 180: % x of 0
    adrp x0, Ltf_fmt_180@PAGE
    add x0, x0, Ltf_fmt_180@PAGEOFF
    adrp x1, Ltf_slots_180@PAGE
    add x1, x1, Ltf_slots_180@PAGEOFF
    mov x2, #180
    bl _sea_printf
    // case 181: % x of 1
    adrp x0, Ltf_fmt_181@PAGE
    add x0, x0, Ltf_fmt_181@PAGEOFF
    adrp x1, Ltf_slots_181@PAGE
    add x1, x1, Ltf_slots_181@PAGEOFF
    mov x2, #181
    bl _sea_printf
    // case 182: % x of 255
    adrp x0, Ltf_fmt_182@PAGE
    add x0, x0, Ltf_fmt_182@PAGEOFF
    adrp x1, Ltf_slots_182@PAGE
    add x1, x1, Ltf_slots_182@PAGEOFF
    mov x2, #182
    bl _sea_printf
    // case 183: % x of -1
    adrp x0, Ltf_fmt_183@PAGE
    add x0, x0, Ltf_fmt_183@PAGEOFF
    adrp x1, Ltf_slots_183@PAGE
    add x1, x1, Ltf_slots_183@PAGEOFF
    mov x2, #183
    bl _sea_printf
    // case 184: % x of -9223372036854775808
    adrp x0, Ltf_fmt_184@PAGE
    add x0, x0, Ltf_fmt_184@PAGEOFF
    adrp x1, Ltf_slots_184@PAGE
    add x1, x1, Ltf_slots_184@PAGEOFF
    mov x2, #184
    bl _sea_printf
    // case 185: % x of 9223372036854775807
    adrp x0, Ltf_fmt_185@PAGE
    add x0, x0, Ltf_fmt_185@PAGEOFF
    adrp x1, Ltf_slots_185@PAGE
    add x1, x1, Ltf_slots_185@PAGEOFF
    mov x2, #185
    bl _sea_printf
    // case 186: % x of 3735928559
    adrp x0, Ltf_fmt_186@PAGE
    add x0, x0, Ltf_fmt_186@PAGEOFF
    adrp x1, Ltf_slots_186@PAGE
    add x1, x1, Ltf_slots_186@PAGEOFF
    mov x2, #186
    bl _sea_printf
    // case 187: % x of 16
    adrp x0, Ltf_fmt_187@PAGE
    add x0, x0, Ltf_fmt_187@PAGEOFF
    adrp x1, Ltf_slots_187@PAGE
    add x1, x1, Ltf_slots_187@PAGEOFF
    mov x2, #187
    bl _sea_printf
    // case 188: % x of 419385573
    adrp x0, Ltf_fmt_188@PAGE
    add x0, x0, Ltf_fmt_188@PAGEOFF
    adrp x1, Ltf_slots_188@PAGE
    add x1, x1, Ltf_slots_188@PAGEOFF
    mov x2, #188
    bl _sea_printf
    // case 189: %+08X of 0
    adrp x0, Ltf_fmt_189@PAGE
    add x0, x0, Ltf_fmt_189@PAGEOFF
    adrp x1, Ltf_slots_189@PAGE
    add x1, x1, Ltf_slots_189@PAGEOFF
    mov x2, #189
    bl _sea_printf
    // case 190: %+08X of 1
    adrp x0, Ltf_fmt_190@PAGE
    add x0, x0, Ltf_fmt_190@PAGEOFF
    adrp x1, Ltf_slots_190@PAGE
    add x1, x1, Ltf_slots_190@PAGEOFF
    mov x2, #190
    bl _sea_printf
    // case 191: %+08X of 255
    adrp x0, Ltf_fmt_191@PAGE
    add x0, x0, Ltf_fmt_191@PAGEOFF
    adrp x1, Ltf_slots_191@PAGE
    add x1, x1, Ltf_slots_191@PAGEOFF
    mov x2, #191
    bl _sea_printf
    // case 192: %+08X of -1
    adrp x0, Ltf_fmt_192@PAGE
    add x0, x0, Ltf_fmt_192@PAGEOFF
    adrp x1, Ltf_slots_192@PAGE
    add x1, x1, Ltf_slots_192@PAGEOFF
    mov x2, #192
    bl _sea_printf
    // case 193: %+08X of -9223372036854775808
    adrp x0, Ltf_fmt_193@PAGE
    add x0, x0, Ltf_fmt_193@PAGEOFF
    adrp x1, Ltf_slots_193@PAGE
    add x1, x1, Ltf_slots_193@PAGEOFF
    mov x2, #193
    bl _sea_printf
    // case 194: %+08X of 9223372036854775807
    adrp x0, Ltf_fmt_194@PAGE
    add x0, x0, Ltf_fmt_194@PAGEOFF
    adrp x1, Ltf_slots_194@PAGE
    add x1, x1, Ltf_slots_194@PAGEOFF
    mov x2, #194
    bl _sea_printf
    // case 195: %+08X of 3735928559
    adrp x0, Ltf_fmt_195@PAGE
    add x0, x0, Ltf_fmt_195@PAGEOFF
    adrp x1, Ltf_slots_195@PAGE
    add x1, x1, Ltf_slots_195@PAGEOFF
    mov x2, #195
    bl _sea_printf
    // case 196: %+08X of 16
    adrp x0, Ltf_fmt_196@PAGE
    add x0, x0, Ltf_fmt_196@PAGEOFF
    adrp x1, Ltf_slots_196@PAGE
    add x1, x1, Ltf_slots_196@PAGEOFF
    mov x2, #196
    bl _sea_printf
    // case 197: %+08X of 419385573
    adrp x0, Ltf_fmt_197@PAGE
    add x0, x0, Ltf_fmt_197@PAGEOFF
    adrp x1, Ltf_slots_197@PAGE
    add x1, x1, Ltf_slots_197@PAGEOFF
    mov x2, #197
    bl _sea_printf
    // case 198: %-+8x| of 0
    adrp x0, Ltf_fmt_198@PAGE
    add x0, x0, Ltf_fmt_198@PAGEOFF
    adrp x1, Ltf_slots_198@PAGE
    add x1, x1, Ltf_slots_198@PAGEOFF
    mov x2, #198
    bl _sea_printf
    // case 199: %-+8x| of 1
    adrp x0, Ltf_fmt_199@PAGE
    add x0, x0, Ltf_fmt_199@PAGEOFF
    adrp x1, Ltf_slots_199@PAGE
    add x1, x1, Ltf_slots_199@PAGEOFF
    mov x2, #199
    bl _sea_printf
    // case 200: %-+8x| of 255
    adrp x0, Ltf_fmt_200@PAGE
    add x0, x0, Ltf_fmt_200@PAGEOFF
    adrp x1, Ltf_slots_200@PAGE
    add x1, x1, Ltf_slots_200@PAGEOFF
    mov x2, #200
    bl _sea_printf
    // case 201: %-+8x| of -1
    adrp x0, Ltf_fmt_201@PAGE
    add x0, x0, Ltf_fmt_201@PAGEOFF
    adrp x1, Ltf_slots_201@PAGE
    add x1, x1, Ltf_slots_201@PAGEOFF
    mov x2, #201
    bl _sea_printf
    // case 202: %-+8x| of -9223372036854775808
    adrp x0, Ltf_fmt_202@PAGE
    add x0, x0, Ltf_fmt_202@PAGEOFF
    adrp x1, Ltf_slots_202@PAGE
    add x1, x1, Ltf_slots_202@PAGEOFF
    mov x2, #202
    bl _sea_printf
    // case 203: %-+8x| of 9223372036854775807
    adrp x0, Ltf_fmt_203@PAGE
    add x0, x0, Ltf_fmt_203@PAGEOFF
    adrp x1, Ltf_slots_203@PAGE
    add x1, x1, Ltf_slots_203@PAGEOFF
    mov x2, #203
    bl _sea_printf
    // case 204: %-+8x| of 3735928559
    adrp x0, Ltf_fmt_204@PAGE
    add x0, x0, Ltf_fmt_204@PAGEOFF
    adrp x1, Ltf_slots_204@PAGE
    add x1, x1, Ltf_slots_204@PAGEOFF
    mov x2, #204
    bl _sea_printf
    // case 205: %-+8x| of 16
    adrp x0, Ltf_fmt_205@PAGE
    add x0, x0, Ltf_fmt_205@PAGEOFF
    adrp x1, Ltf_slots_205@PAGE
    add x1, x1, Ltf_slots_205@PAGEOFF
    mov x2, #205
    bl _sea_printf
    // case 206: %-+8x| of 419385573
    adrp x0, Ltf_fmt_206@PAGE
    add x0, x0, Ltf_fmt_206@PAGEOFF
    adrp x1, Ltf_slots_206@PAGE
    add x1, x1, Ltf_slots_206@PAGEOFF
    mov x2, #206
    bl _sea_printf
    // case 207: %#+x of 0
    adrp x0, Ltf_fmt_207@PAGE
    add x0, x0, Ltf_fmt_207@PAGEOFF
    adrp x1, Ltf_slots_207@PAGE
    add x1, x1, Ltf_slots_207@PAGEOFF
    mov x2, #207
    bl _sea_printf
    // case 208: %#+x of 1
    adrp x0, Ltf_fmt_208@PAGE
    add x0, x0, Ltf_fmt_208@PAGEOFF
    adrp x1, Ltf_slots_208@PAGE
    add x1, x1, Ltf_slots_208@PAGEOFF
    mov x2, #208
    bl _sea_printf
    // case 209: %#+x of 255
    adrp x0, Ltf_fmt_209@PAGE
    add x0, x0, Ltf_fmt_209@PAGEOFF
    adrp x1, Ltf_slots_209@PAGE
    add x1, x1, Ltf_slots_209@PAGEOFF
    mov x2, #209
    bl _sea_printf
    // case 210: %#+x of -1
    adrp x0, Ltf_fmt_210@PAGE
    add x0, x0, Ltf_fmt_210@PAGEOFF
    adrp x1, Ltf_slots_210@PAGE
    add x1, x1, Ltf_slots_210@PAGEOFF
    mov x2, #210
    bl _sea_printf
    // case 211: %#+x of -9223372036854775808
    adrp x0, Ltf_fmt_211@PAGE
    add x0, x0, Ltf_fmt_211@PAGEOFF
    adrp x1, Ltf_slots_211@PAGE
    add x1, x1, Ltf_slots_211@PAGEOFF
    mov x2, #211
    bl _sea_printf
    // case 212: %#+x of 9223372036854775807
    adrp x0, Ltf_fmt_212@PAGE
    add x0, x0, Ltf_fmt_212@PAGEOFF
    adrp x1, Ltf_slots_212@PAGE
    add x1, x1, Ltf_slots_212@PAGEOFF
    mov x2, #212
    bl _sea_printf
    // case 213: %#+x of 3735928559
    adrp x0, Ltf_fmt_213@PAGE
    add x0, x0, Ltf_fmt_213@PAGEOFF
    adrp x1, Ltf_slots_213@PAGE
    add x1, x1, Ltf_slots_213@PAGEOFF
    mov x2, #213
    bl _sea_printf
    // case 214: %#+x of 16
    adrp x0, Ltf_fmt_214@PAGE
    add x0, x0, Ltf_fmt_214@PAGEOFF
    adrp x1, Ltf_slots_214@PAGE
    add x1, x1, Ltf_slots_214@PAGEOFF
    mov x2, #214
    bl _sea_printf
    // case 215: %#+x of 419385573
    adrp x0, Ltf_fmt_215@PAGE
    add x0, x0, Ltf_fmt_215@PAGEOFF
    adrp x1, Ltf_slots_215@PAGE
    add x1, x1, Ltf_slots_215@PAGEOFF
    mov x2, #215
    bl _sea_printf
    // case 216: %20x of 0
    adrp x0, Ltf_fmt_216@PAGE
    add x0, x0, Ltf_fmt_216@PAGEOFF
    adrp x1, Ltf_slots_216@PAGE
    add x1, x1, Ltf_slots_216@PAGEOFF
    mov x2, #216
    bl _sea_printf
    // case 217: %20x of 1
    adrp x0, Ltf_fmt_217@PAGE
    add x0, x0, Ltf_fmt_217@PAGEOFF
    adrp x1, Ltf_slots_217@PAGE
    add x1, x1, Ltf_slots_217@PAGEOFF
    mov x2, #217
    bl _sea_printf
    // case 218: %20x of 255
    adrp x0, Ltf_fmt_218@PAGE
    add x0, x0, Ltf_fmt_218@PAGEOFF
    adrp x1, Ltf_slots_218@PAGE
    add x1, x1, Ltf_slots_218@PAGEOFF
    mov x2, #218
    bl _sea_printf
    // case 219: %20x of -1
    adrp x0, Ltf_fmt_219@PAGE
    add x0, x0, Ltf_fmt_219@PAGEOFF
    adrp x1, Ltf_slots_219@PAGE
    add x1, x1, Ltf_slots_219@PAGEOFF
    mov x2, #219
    bl _sea_printf
    // case 220: %20x of -9223372036854775808
    adrp x0, Ltf_fmt_220@PAGE
    add x0, x0, Ltf_fmt_220@PAGEOFF
    adrp x1, Ltf_slots_220@PAGE
    add x1, x1, Ltf_slots_220@PAGEOFF
    mov x2, #220
    bl _sea_printf
    // case 221: %20x of 9223372036854775807
    adrp x0, Ltf_fmt_221@PAGE
    add x0, x0, Ltf_fmt_221@PAGEOFF
    adrp x1, Ltf_slots_221@PAGE
    add x1, x1, Ltf_slots_221@PAGEOFF
    mov x2, #221
    bl _sea_printf
    // case 222: %20x of 3735928559
    adrp x0, Ltf_fmt_222@PAGE
    add x0, x0, Ltf_fmt_222@PAGEOFF
    adrp x1, Ltf_slots_222@PAGE
    add x1, x1, Ltf_slots_222@PAGEOFF
    mov x2, #222
    bl _sea_printf
    // case 223: %20x of 16
    adrp x0, Ltf_fmt_223@PAGE
    add x0, x0, Ltf_fmt_223@PAGEOFF
    adrp x1, Ltf_slots_223@PAGE
    add x1, x1, Ltf_slots_223@PAGEOFF
    mov x2, #223
    bl _sea_printf
    // case 224: %20x of 419385573
    adrp x0, Ltf_fmt_224@PAGE
    add x0, x0, Ltf_fmt_224@PAGEOFF
    adrp x1, Ltf_slots_224@PAGE
    add x1, x1, Ltf_slots_224@PAGEOFF
    mov x2, #224
    bl _sea_printf
    // case 225: %020X of 0
    adrp x0, Ltf_fmt_225@PAGE
    add x0, x0, Ltf_fmt_225@PAGEOFF
    adrp x1, Ltf_slots_225@PAGE
    add x1, x1, Ltf_slots_225@PAGEOFF
    mov x2, #225
    bl _sea_printf
    // case 226: %020X of 1
    adrp x0, Ltf_fmt_226@PAGE
    add x0, x0, Ltf_fmt_226@PAGEOFF
    adrp x1, Ltf_slots_226@PAGE
    add x1, x1, Ltf_slots_226@PAGEOFF
    mov x2, #226
    bl _sea_printf
    // case 227: %020X of 255
    adrp x0, Ltf_fmt_227@PAGE
    add x0, x0, Ltf_fmt_227@PAGEOFF
    adrp x1, Ltf_slots_227@PAGE
    add x1, x1, Ltf_slots_227@PAGEOFF
    mov x2, #227
    bl _sea_printf
    // case 228: %020X of -1
    adrp x0, Ltf_fmt_228@PAGE
    add x0, x0, Ltf_fmt_228@PAGEOFF
    adrp x1, Ltf_slots_228@PAGE
    add x1, x1, Ltf_slots_228@PAGEOFF
    mov x2, #228
    bl _sea_printf
    // case 229: %020X of -9223372036854775808
    adrp x0, Ltf_fmt_229@PAGE
    add x0, x0, Ltf_fmt_229@PAGEOFF
    adrp x1, Ltf_slots_229@PAGE
    add x1, x1, Ltf_slots_229@PAGEOFF
    mov x2, #229
    bl _sea_printf
    // case 230: %020X of 9223372036854775807
    adrp x0, Ltf_fmt_230@PAGE
    add x0, x0, Ltf_fmt_230@PAGEOFF
    adrp x1, Ltf_slots_230@PAGE
    add x1, x1, Ltf_slots_230@PAGEOFF
    mov x2, #230
    bl _sea_printf
    // case 231: %020X of 3735928559
    adrp x0, Ltf_fmt_231@PAGE
    add x0, x0, Ltf_fmt_231@PAGEOFF
    adrp x1, Ltf_slots_231@PAGE
    add x1, x1, Ltf_slots_231@PAGEOFF
    mov x2, #231
    bl _sea_printf
    // case 232: %020X of 16
    adrp x0, Ltf_fmt_232@PAGE
    add x0, x0, Ltf_fmt_232@PAGEOFF
    adrp x1, Ltf_slots_232@PAGE
    add x1, x1, Ltf_slots_232@PAGEOFF
    mov x2, #232
    bl _sea_printf
    // case 233: %020X of 419385573
    adrp x0, Ltf_fmt_233@PAGE
    add x0, x0, Ltf_fmt_233@PAGEOFF
    adrp x1, Ltf_slots_233@PAGE
    add x1, x1, Ltf_slots_233@PAGEOFF
    mov x2, #233
    bl _sea_printf
    // case 234: %.16x of 0
    adrp x0, Ltf_fmt_234@PAGE
    add x0, x0, Ltf_fmt_234@PAGEOFF
    adrp x1, Ltf_slots_234@PAGE
    add x1, x1, Ltf_slots_234@PAGEOFF
    mov x2, #234
    bl _sea_printf
    // case 235: %.16x of 1
    adrp x0, Ltf_fmt_235@PAGE
    add x0, x0, Ltf_fmt_235@PAGEOFF
    adrp x1, Ltf_slots_235@PAGE
    add x1, x1, Ltf_slots_235@PAGEOFF
    mov x2, #235
    bl _sea_printf
    // case 236: %.16x of 255
    adrp x0, Ltf_fmt_236@PAGE
    add x0, x0, Ltf_fmt_236@PAGEOFF
    adrp x1, Ltf_slots_236@PAGE
    add x1, x1, Ltf_slots_236@PAGEOFF
    mov x2, #236
    bl _sea_printf
    // case 237: %.16x of -1
    adrp x0, Ltf_fmt_237@PAGE
    add x0, x0, Ltf_fmt_237@PAGEOFF
    adrp x1, Ltf_slots_237@PAGE
    add x1, x1, Ltf_slots_237@PAGEOFF
    mov x2, #237
    bl _sea_printf
    // case 238: %.16x of -9223372036854775808
    adrp x0, Ltf_fmt_238@PAGE
    add x0, x0, Ltf_fmt_238@PAGEOFF
    adrp x1, Ltf_slots_238@PAGE
    add x1, x1, Ltf_slots_238@PAGEOFF
    mov x2, #238
    bl _sea_printf
    // case 239: %.16x of 9223372036854775807
    adrp x0, Ltf_fmt_239@PAGE
    add x0, x0, Ltf_fmt_239@PAGEOFF
    adrp x1, Ltf_slots_239@PAGE
    add x1, x1, Ltf_slots_239@PAGEOFF
    mov x2, #239
    bl _sea_printf
    // case 240: %.16x of 3735928559
    adrp x0, Ltf_fmt_240@PAGE
    add x0, x0, Ltf_fmt_240@PAGEOFF
    adrp x1, Ltf_slots_240@PAGE
    add x1, x1, Ltf_slots_240@PAGEOFF
    mov x2, #240
    bl _sea_printf
    // case 241: %.16x of 16
    adrp x0, Ltf_fmt_241@PAGE
    add x0, x0, Ltf_fmt_241@PAGEOFF
    adrp x1, Ltf_slots_241@PAGE
    add x1, x1, Ltf_slots_241@PAGEOFF
    mov x2, #241
    bl _sea_printf
    // case 242: %.16x of 419385573
    adrp x0, Ltf_fmt_242@PAGE
    add x0, x0, Ltf_fmt_242@PAGEOFF
    adrp x1, Ltf_slots_242@PAGE
    add x1, x1, Ltf_slots_242@PAGEOFF
    mov x2, #242
    bl _sea_printf
    // case 243: %.20x of 0
    adrp x0, Ltf_fmt_243@PAGE
    add x0, x0, Ltf_fmt_243@PAGEOFF
    adrp x1, Ltf_slots_243@PAGE
    add x1, x1, Ltf_slots_243@PAGEOFF
    mov x2, #243
    bl _sea_printf
    // case 244: %.20x of 1
    adrp x0, Ltf_fmt_244@PAGE
    add x0, x0, Ltf_fmt_244@PAGEOFF
    adrp x1, Ltf_slots_244@PAGE
    add x1, x1, Ltf_slots_244@PAGEOFF
    mov x2, #244
    bl _sea_printf
    // case 245: %.20x of 255
    adrp x0, Ltf_fmt_245@PAGE
    add x0, x0, Ltf_fmt_245@PAGEOFF
    adrp x1, Ltf_slots_245@PAGE
    add x1, x1, Ltf_slots_245@PAGEOFF
    mov x2, #245
    bl _sea_printf
    // case 246: %.20x of -1
    adrp x0, Ltf_fmt_246@PAGE
    add x0, x0, Ltf_fmt_246@PAGEOFF
    adrp x1, Ltf_slots_246@PAGE
    add x1, x1, Ltf_slots_246@PAGEOFF
    mov x2, #246
    bl _sea_printf
    // case 247: %.20x of -9223372036854775808
    adrp x0, Ltf_fmt_247@PAGE
    add x0, x0, Ltf_fmt_247@PAGEOFF
    adrp x1, Ltf_slots_247@PAGE
    add x1, x1, Ltf_slots_247@PAGEOFF
    mov x2, #247
    bl _sea_printf
    // case 248: %.20x of 9223372036854775807
    adrp x0, Ltf_fmt_248@PAGE
    add x0, x0, Ltf_fmt_248@PAGEOFF
    adrp x1, Ltf_slots_248@PAGE
    add x1, x1, Ltf_slots_248@PAGEOFF
    mov x2, #248
    bl _sea_printf
    // case 249: %.20x of 3735928559
    adrp x0, Ltf_fmt_249@PAGE
    add x0, x0, Ltf_fmt_249@PAGEOFF
    adrp x1, Ltf_slots_249@PAGE
    add x1, x1, Ltf_slots_249@PAGEOFF
    mov x2, #249
    bl _sea_printf
    // case 250: %.20x of 16
    adrp x0, Ltf_fmt_250@PAGE
    add x0, x0, Ltf_fmt_250@PAGEOFF
    adrp x1, Ltf_slots_250@PAGE
    add x1, x1, Ltf_slots_250@PAGEOFF
    mov x2, #250
    bl _sea_printf
    // case 251: %.20x of 419385573
    adrp x0, Ltf_fmt_251@PAGE
    add x0, x0, Ltf_fmt_251@PAGEOFF
    adrp x1, Ltf_slots_251@PAGE
    add x1, x1, Ltf_slots_251@PAGEOFF
    mov x2, #251
    bl _sea_printf
    // case 252: %#.20X of 0
    adrp x0, Ltf_fmt_252@PAGE
    add x0, x0, Ltf_fmt_252@PAGEOFF
    adrp x1, Ltf_slots_252@PAGE
    add x1, x1, Ltf_slots_252@PAGEOFF
    mov x2, #252
    bl _sea_printf
    // case 253: %#.20X of 1
    adrp x0, Ltf_fmt_253@PAGE
    add x0, x0, Ltf_fmt_253@PAGEOFF
    adrp x1, Ltf_slots_253@PAGE
    add x1, x1, Ltf_slots_253@PAGEOFF
    mov x2, #253
    bl _sea_printf
    // case 254: %#.20X of 255
    adrp x0, Ltf_fmt_254@PAGE
    add x0, x0, Ltf_fmt_254@PAGEOFF
    adrp x1, Ltf_slots_254@PAGE
    add x1, x1, Ltf_slots_254@PAGEOFF
    mov x2, #254
    bl _sea_printf
    // case 255: %#.20X of -1
    adrp x0, Ltf_fmt_255@PAGE
    add x0, x0, Ltf_fmt_255@PAGEOFF
    adrp x1, Ltf_slots_255@PAGE
    add x1, x1, Ltf_slots_255@PAGEOFF
    mov x2, #255
    bl _sea_printf
    // case 256: %#.20X of -9223372036854775808
    adrp x0, Ltf_fmt_256@PAGE
    add x0, x0, Ltf_fmt_256@PAGEOFF
    adrp x1, Ltf_slots_256@PAGE
    add x1, x1, Ltf_slots_256@PAGEOFF
    mov x2, #256
    bl _sea_printf
    // case 257: %#.20X of 9223372036854775807
    adrp x0, Ltf_fmt_257@PAGE
    add x0, x0, Ltf_fmt_257@PAGEOFF
    adrp x1, Ltf_slots_257@PAGE
    add x1, x1, Ltf_slots_257@PAGEOFF
    mov x2, #257
    bl _sea_printf
    // case 258: %#.20X of 3735928559
    adrp x0, Ltf_fmt_258@PAGE
    add x0, x0, Ltf_fmt_258@PAGEOFF
    adrp x1, Ltf_slots_258@PAGE
    add x1, x1, Ltf_slots_258@PAGEOFF
    mov x2, #258
    bl _sea_printf
    // case 259: %#.20X of 16
    adrp x0, Ltf_fmt_259@PAGE
    add x0, x0, Ltf_fmt_259@PAGEOFF
    adrp x1, Ltf_slots_259@PAGE
    add x1, x1, Ltf_slots_259@PAGEOFF
    mov x2, #259
    bl _sea_printf
    // case 260: %#.20X of 419385573
    adrp x0, Ltf_fmt_260@PAGE
    add x0, x0, Ltf_fmt_260@PAGEOFF
    adrp x1, Ltf_slots_260@PAGE
    add x1, x1, Ltf_slots_260@PAGEOFF
    mov x2, #260
    bl _sea_printf
    // case 261: %2x of 0
    adrp x0, Ltf_fmt_261@PAGE
    add x0, x0, Ltf_fmt_261@PAGEOFF
    adrp x1, Ltf_slots_261@PAGE
    add x1, x1, Ltf_slots_261@PAGEOFF
    mov x2, #261
    bl _sea_printf
    // case 262: %2x of 1
    adrp x0, Ltf_fmt_262@PAGE
    add x0, x0, Ltf_fmt_262@PAGEOFF
    adrp x1, Ltf_slots_262@PAGE
    add x1, x1, Ltf_slots_262@PAGEOFF
    mov x2, #262
    bl _sea_printf
    // case 263: %2x of 255
    adrp x0, Ltf_fmt_263@PAGE
    add x0, x0, Ltf_fmt_263@PAGEOFF
    adrp x1, Ltf_slots_263@PAGE
    add x1, x1, Ltf_slots_263@PAGEOFF
    mov x2, #263
    bl _sea_printf
    // case 264: %2x of -1
    adrp x0, Ltf_fmt_264@PAGE
    add x0, x0, Ltf_fmt_264@PAGEOFF
    adrp x1, Ltf_slots_264@PAGE
    add x1, x1, Ltf_slots_264@PAGEOFF
    mov x2, #264
    bl _sea_printf
    // case 265: %2x of -9223372036854775808
    adrp x0, Ltf_fmt_265@PAGE
    add x0, x0, Ltf_fmt_265@PAGEOFF
    adrp x1, Ltf_slots_265@PAGE
    add x1, x1, Ltf_slots_265@PAGEOFF
    mov x2, #265
    bl _sea_printf
    // case 266: %2x of 9223372036854775807
    adrp x0, Ltf_fmt_266@PAGE
    add x0, x0, Ltf_fmt_266@PAGEOFF
    adrp x1, Ltf_slots_266@PAGE
    add x1, x1, Ltf_slots_266@PAGEOFF
    mov x2, #266
    bl _sea_printf
    // case 267: %2x of 3735928559
    adrp x0, Ltf_fmt_267@PAGE
    add x0, x0, Ltf_fmt_267@PAGEOFF
    adrp x1, Ltf_slots_267@PAGE
    add x1, x1, Ltf_slots_267@PAGEOFF
    mov x2, #267
    bl _sea_printf
    // case 268: %2x of 16
    adrp x0, Ltf_fmt_268@PAGE
    add x0, x0, Ltf_fmt_268@PAGEOFF
    adrp x1, Ltf_slots_268@PAGE
    add x1, x1, Ltf_slots_268@PAGEOFF
    mov x2, #268
    bl _sea_printf
    // case 269: %2x of 419385573
    adrp x0, Ltf_fmt_269@PAGE
    add x0, x0, Ltf_fmt_269@PAGEOFF
    adrp x1, Ltf_slots_269@PAGE
    add x1, x1, Ltf_slots_269@PAGEOFF
    mov x2, #269
    bl _sea_printf
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 3
Ltf_fmt_0:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_0_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_0_2, 2
    .p2align 3
Ltf_slots_0:
    .quad 0
Ltf_text_0_0:
    .byte 91
Ltf_text_0_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_1:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_1_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_1_2, 2
    .p2align 3
Ltf_slots_1:
    .quad 1
Ltf_text_1_0:
    .byte 91
Ltf_text_1_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_2:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_2_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_2_2, 2
    .p2align 3
Ltf_slots_2:
    .quad 255
Ltf_text_2_0:
    .byte 91
Ltf_text_2_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_3:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_3_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_3_2, 2
    .p2align 3
Ltf_slots_3:
    .quad -1
Ltf_text_3_0:
    .byte 91
Ltf_text_3_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_4:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_4_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_4_2, 2
    .p2align 3
Ltf_slots_4:
    .quad -9223372036854775808
Ltf_text_4_0:
    .byte 91
Ltf_text_4_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_5:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_5_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_5_2, 2
    .p2align 3
Ltf_slots_5:
    .quad 9223372036854775807
Ltf_text_5_0:
    .byte 91
Ltf_text_5_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_6:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_6_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_6_2, 2
    .p2align 3
Ltf_slots_6:
    .quad 3735928559
Ltf_text_6_0:
    .byte 91
Ltf_text_6_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_7:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_7_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_7_2, 2
    .p2align 3
Ltf_slots_7:
    .quad 16
Ltf_text_7_0:
    .byte 91
Ltf_text_7_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_8:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_8_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_8_2, 2
    .p2align 3
Ltf_slots_8:
    .quad 419385573
Ltf_text_8_0:
    .byte 91
Ltf_text_8_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_9:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_9_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_9_2, 2
    .p2align 3
Ltf_slots_9:
    .quad 0
Ltf_text_9_0:
    .byte 91
Ltf_text_9_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_10:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_10_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_10_2, 2
    .p2align 3
Ltf_slots_10:
    .quad 1
Ltf_text_10_0:
    .byte 91
Ltf_text_10_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_11:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_11_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_11_2, 2
    .p2align 3
Ltf_slots_11:
    .quad 255
Ltf_text_11_0:
    .byte 91
Ltf_text_11_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_12:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_12_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_12_2, 2
    .p2align 3
Ltf_slots_12:
    .quad -1
Ltf_text_12_0:
    .byte 91
Ltf_text_12_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_13:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_13_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_13_2, 2
    .p2align 3
Ltf_slots_13:
    .quad -9223372036854775808
Ltf_text_13_0:
    .byte 91
Ltf_text_13_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_14:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_14_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_14_2, 2
    .p2align 3
Ltf_slots_14:
    .quad 9223372036854775807
Ltf_text_14_0:
    .byte 91
Ltf_text_14_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_15:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_15_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_15_2, 2
    .p2align 3
Ltf_slots_15:
    .quad 3735928559
Ltf_text_15_0:
    .byte 91
Ltf_text_15_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_16:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_16_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_16_2, 2
    .p2align 3
Ltf_slots_16:
    .quad 16
Ltf_text_16_0:
    .byte 91
Ltf_text_16_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_17:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_17_0, 1
    .byte SEA_FPK_CONV, 'X', 0, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_17_2, 2
    .p2align 3
Ltf_slots_17:
    .quad 419385573
Ltf_text_17_0:
    .byte 91
Ltf_text_17_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_18:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_18_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_18_2, 2
    .p2align 3
Ltf_slots_18:
    .quad 0
Ltf_text_18_0:
    .byte 91
Ltf_text_18_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_19:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_19_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_19_2, 2
    .p2align 3
Ltf_slots_19:
    .quad 1
Ltf_text_19_0:
    .byte 91
Ltf_text_19_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_20:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_20_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_20_2, 2
    .p2align 3
Ltf_slots_20:
    .quad 255
Ltf_text_20_0:
    .byte 91
Ltf_text_20_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_21:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_21_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_21_2, 2
    .p2align 3
Ltf_slots_21:
    .quad -1
Ltf_text_21_0:
    .byte 91
Ltf_text_21_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_22:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_22_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_22_2, 2
    .p2align 3
Ltf_slots_22:
    .quad -9223372036854775808
Ltf_text_22_0:
    .byte 91
Ltf_text_22_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_23:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_23_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_23_2, 2
    .p2align 3
Ltf_slots_23:
    .quad 9223372036854775807
Ltf_text_23_0:
    .byte 91
Ltf_text_23_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_24:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_24_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_24_2, 2
    .p2align 3
Ltf_slots_24:
    .quad 3735928559
Ltf_text_24_0:
    .byte 91
Ltf_text_24_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_25:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_25_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_25_2, 2
    .p2align 3
Ltf_slots_25:
    .quad 16
Ltf_text_25_0:
    .byte 91
Ltf_text_25_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_26:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_26_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_26_2, 2
    .p2align 3
Ltf_slots_26:
    .quad 419385573
Ltf_text_26_0:
    .byte 91
Ltf_text_26_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_27:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_27_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_27_2, 2
    .p2align 3
Ltf_slots_27:
    .quad 0
Ltf_text_27_0:
    .byte 91
Ltf_text_27_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_28:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_28_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_28_2, 2
    .p2align 3
Ltf_slots_28:
    .quad 1
Ltf_text_28_0:
    .byte 91
Ltf_text_28_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_29:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_29_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_29_2, 2
    .p2align 3
Ltf_slots_29:
    .quad 255
Ltf_text_29_0:
    .byte 91
Ltf_text_29_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_30:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_30_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_30_2, 2
    .p2align 3
Ltf_slots_30:
    .quad -1
Ltf_text_30_0:
    .byte 91
Ltf_text_30_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_31:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_31_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_31_2, 2
    .p2align 3
Ltf_slots_31:
    .quad -9223372036854775808
Ltf_text_31_0:
    .byte 91
Ltf_text_31_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_32:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_32_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_32_2, 2
    .p2align 3
Ltf_slots_32:
    .quad 9223372036854775807
Ltf_text_32_0:
    .byte 91
Ltf_text_32_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_33:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_33_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_33_2, 2
    .p2align 3
Ltf_slots_33:
    .quad 3735928559
Ltf_text_33_0:
    .byte 91
Ltf_text_33_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_34:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_34_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_34_2, 2
    .p2align 3
Ltf_slots_34:
    .quad 16
Ltf_text_34_0:
    .byte 91
Ltf_text_34_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_35:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_35_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_35_2, 2
    .p2align 3
Ltf_slots_35:
    .quad 419385573
Ltf_text_35_0:
    .byte 91
Ltf_text_35_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_36:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_36_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_36_2, 2
    .p2align 3
Ltf_slots_36:
    .quad 0
Ltf_text_36_0:
    .byte 91
Ltf_text_36_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_37:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_37_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_37_2, 2
    .p2align 3
Ltf_slots_37:
    .quad 1
Ltf_text_37_0:
    .byte 91
Ltf_text_37_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_38:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_38_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_38_2, 2
    .p2align 3
Ltf_slots_38:
    .quad 255
Ltf_text_38_0:
    .byte 91
Ltf_text_38_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_39:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_39_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_39_2, 2
    .p2align 3
Ltf_slots_39:
    .quad -1
Ltf_text_39_0:
    .byte 91
Ltf_text_39_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_40:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_40_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_40_2, 2
    .p2align 3
Ltf_slots_40:
    .quad -9223372036854775808
Ltf_text_40_0:
    .byte 91
Ltf_text_40_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_41:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_41_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_41_2, 2
    .p2align 3
Ltf_slots_41:
    .quad 9223372036854775807
Ltf_text_41_0:
    .byte 91
Ltf_text_41_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_42:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_42_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_42_2, 2
    .p2align 3
Ltf_slots_42:
    .quad 3735928559
Ltf_text_42_0:
    .byte 91
Ltf_text_42_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_43:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_43_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_43_2, 2
    .p2align 3
Ltf_slots_43:
    .quad 16
Ltf_text_43_0:
    .byte 91
Ltf_text_43_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_44:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_44_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_44_2, 2
    .p2align 3
Ltf_slots_44:
    .quad 419385573
Ltf_text_44_0:
    .byte 91
Ltf_text_44_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_45:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_45_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_45_2, 2
    .p2align 3
Ltf_slots_45:
    .quad 0
Ltf_text_45_0:
    .byte 91
Ltf_text_45_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_46:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_46_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_46_2, 2
    .p2align 3
Ltf_slots_46:
    .quad 1
Ltf_text_46_0:
    .byte 91
Ltf_text_46_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_47:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_47_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_47_2, 2
    .p2align 3
Ltf_slots_47:
    .quad 255
Ltf_text_47_0:
    .byte 91
Ltf_text_47_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_48:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_48_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_48_2, 2
    .p2align 3
Ltf_slots_48:
    .quad -1
Ltf_text_48_0:
    .byte 91
Ltf_text_48_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_49:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_49_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_49_2, 2
    .p2align 3
Ltf_slots_49:
    .quad -9223372036854775808
Ltf_text_49_0:
    .byte 91
Ltf_text_49_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_50:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_50_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_50_2, 2
    .p2align 3
Ltf_slots_50:
    .quad 9223372036854775807
Ltf_text_50_0:
    .byte 91
Ltf_text_50_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_51:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_51_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_51_2, 2
    .p2align 3
Ltf_slots_51:
    .quad 3735928559
Ltf_text_51_0:
    .byte 91
Ltf_text_51_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_52:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_52_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_52_2, 2
    .p2align 3
Ltf_slots_52:
    .quad 16
Ltf_text_52_0:
    .byte 91
Ltf_text_52_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_53:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_53_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_53_2, 2
    .p2align 3
Ltf_slots_53:
    .quad 419385573
Ltf_text_53_0:
    .byte 91
Ltf_text_53_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_54:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_54_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_54_2, 2
    .p2align 3
Ltf_slots_54:
    .quad 0
Ltf_text_54_0:
    .byte 91
Ltf_text_54_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_55:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_55_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_55_2, 2
    .p2align 3
Ltf_slots_55:
    .quad 1
Ltf_text_55_0:
    .byte 91
Ltf_text_55_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_56:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_56_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_56_2, 2
    .p2align 3
Ltf_slots_56:
    .quad 255
Ltf_text_56_0:
    .byte 91
Ltf_text_56_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_57:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_57_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_57_2, 2
    .p2align 3
Ltf_slots_57:
    .quad -1
Ltf_text_57_0:
    .byte 91
Ltf_text_57_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_58:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_58_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_58_2, 2
    .p2align 3
Ltf_slots_58:
    .quad -9223372036854775808
Ltf_text_58_0:
    .byte 91
Ltf_text_58_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_59:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_59_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_59_2, 2
    .p2align 3
Ltf_slots_59:
    .quad 9223372036854775807
Ltf_text_59_0:
    .byte 91
Ltf_text_59_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_60:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_60_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_60_2, 2
    .p2align 3
Ltf_slots_60:
    .quad 3735928559
Ltf_text_60_0:
    .byte 91
Ltf_text_60_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_61:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_61_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_61_2, 2
    .p2align 3
Ltf_slots_61:
    .quad 16
Ltf_text_61_0:
    .byte 91
Ltf_text_61_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_62:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_62_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_62_2, 2
    .p2align 3
Ltf_slots_62:
    .quad 419385573
Ltf_text_62_0:
    .byte 91
Ltf_text_62_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_63:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_63_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_63_2, 2
    .p2align 3
Ltf_slots_63:
    .quad 0
Ltf_text_63_0:
    .byte 91
Ltf_text_63_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_64:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_64_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_64_2, 2
    .p2align 3
Ltf_slots_64:
    .quad 1
Ltf_text_64_0:
    .byte 91
Ltf_text_64_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_65:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_65_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_65_2, 2
    .p2align 3
Ltf_slots_65:
    .quad 255
Ltf_text_65_0:
    .byte 91
Ltf_text_65_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_66:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_66_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_66_2, 2
    .p2align 3
Ltf_slots_66:
    .quad -1
Ltf_text_66_0:
    .byte 91
Ltf_text_66_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_67:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_67_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_67_2, 2
    .p2align 3
Ltf_slots_67:
    .quad -9223372036854775808
Ltf_text_67_0:
    .byte 91
Ltf_text_67_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_68:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_68_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_68_2, 2
    .p2align 3
Ltf_slots_68:
    .quad 9223372036854775807
Ltf_text_68_0:
    .byte 91
Ltf_text_68_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_69:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_69_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_69_2, 2
    .p2align 3
Ltf_slots_69:
    .quad 3735928559
Ltf_text_69_0:
    .byte 91
Ltf_text_69_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_70:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_70_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_70_2, 2
    .p2align 3
Ltf_slots_70:
    .quad 16
Ltf_text_70_0:
    .byte 91
Ltf_text_70_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_71:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_71_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 10, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_71_2, 2
    .p2align 3
Ltf_slots_71:
    .quad 419385573
Ltf_text_71_0:
    .byte 91
Ltf_text_71_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_72:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_72_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_72_2, 2
    .p2align 3
Ltf_slots_72:
    .quad 0
Ltf_text_72_0:
    .byte 91
Ltf_text_72_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_73:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_73_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_73_2, 2
    .p2align 3
Ltf_slots_73:
    .quad 1
Ltf_text_73_0:
    .byte 91
Ltf_text_73_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_74:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_74_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_74_2, 2
    .p2align 3
Ltf_slots_74:
    .quad 255
Ltf_text_74_0:
    .byte 91
Ltf_text_74_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_75:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_75_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_75_2, 2
    .p2align 3
Ltf_slots_75:
    .quad -1
Ltf_text_75_0:
    .byte 91
Ltf_text_75_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_76:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_76_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_76_2, 2
    .p2align 3
Ltf_slots_76:
    .quad -9223372036854775808
Ltf_text_76_0:
    .byte 91
Ltf_text_76_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_77:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_77_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_77_2, 2
    .p2align 3
Ltf_slots_77:
    .quad 9223372036854775807
Ltf_text_77_0:
    .byte 91
Ltf_text_77_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_78:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_78_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_78_2, 2
    .p2align 3
Ltf_slots_78:
    .quad 3735928559
Ltf_text_78_0:
    .byte 91
Ltf_text_78_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_79:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_79_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_79_2, 2
    .p2align 3
Ltf_slots_79:
    .quad 16
Ltf_text_79_0:
    .byte 91
Ltf_text_79_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_80:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_80_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_80_2, 2
    .p2align 3
Ltf_slots_80:
    .quad 419385573
Ltf_text_80_0:
    .byte 91
Ltf_text_80_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_81:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_81_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_81_2, 2
    .p2align 3
Ltf_slots_81:
    .quad 0
Ltf_text_81_0:
    .byte 91
Ltf_text_81_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_82:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_82_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_82_2, 2
    .p2align 3
Ltf_slots_82:
    .quad 1
Ltf_text_82_0:
    .byte 91
Ltf_text_82_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_83:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_83_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_83_2, 2
    .p2align 3
Ltf_slots_83:
    .quad 255
Ltf_text_83_0:
    .byte 91
Ltf_text_83_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_84:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_84_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_84_2, 2
    .p2align 3
Ltf_slots_84:
    .quad -1
Ltf_text_84_0:
    .byte 91
Ltf_text_84_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_85:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_85_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_85_2, 2
    .p2align 3
Ltf_slots_85:
    .quad -9223372036854775808
Ltf_text_85_0:
    .byte 91
Ltf_text_85_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_86:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_86_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_86_2, 2
    .p2align 3
Ltf_slots_86:
    .quad 9223372036854775807
Ltf_text_86_0:
    .byte 91
Ltf_text_86_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_87:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_87_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_87_2, 2
    .p2align 3
Ltf_slots_87:
    .quad 3735928559
Ltf_text_87_0:
    .byte 91
Ltf_text_87_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_88:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_88_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_88_2, 2
    .p2align 3
Ltf_slots_88:
    .quad 16
Ltf_text_88_0:
    .byte 91
Ltf_text_88_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_89:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_89_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_89_2, 2
    .p2align 3
Ltf_slots_89:
    .quad 419385573
Ltf_text_89_0:
    .byte 91
Ltf_text_89_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_90:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_90_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_90_2, 2
    .p2align 3
Ltf_slots_90:
    .quad 0
Ltf_text_90_0:
    .byte 91
Ltf_text_90_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_91:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_91_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_91_2, 2
    .p2align 3
Ltf_slots_91:
    .quad 1
Ltf_text_91_0:
    .byte 91
Ltf_text_91_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_92:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_92_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_92_2, 2
    .p2align 3
Ltf_slots_92:
    .quad 255
Ltf_text_92_0:
    .byte 91
Ltf_text_92_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_93:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_93_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_93_2, 2
    .p2align 3
Ltf_slots_93:
    .quad -1
Ltf_text_93_0:
    .byte 91
Ltf_text_93_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_94:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_94_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_94_2, 2
    .p2align 3
Ltf_slots_94:
    .quad -9223372036854775808
Ltf_text_94_0:
    .byte 91
Ltf_text_94_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_95:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_95_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_95_2, 2
    .p2align 3
Ltf_slots_95:
    .quad 9223372036854775807
Ltf_text_95_0:
    .byte 91
Ltf_text_95_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_96:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_96_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_96_2, 2
    .p2align 3
Ltf_slots_96:
    .quad 3735928559
Ltf_text_96_0:
    .byte 91
Ltf_text_96_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_97:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_97_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_97_2, 2
    .p2align 3
Ltf_slots_97:
    .quad 16
Ltf_text_97_0:
    .byte 91
Ltf_text_97_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_98:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_98_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long -1, 0, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_98_2, 2
    .p2align 3
Ltf_slots_98:
    .quad 419385573
Ltf_text_98_0:
    .byte 91
Ltf_text_98_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_99:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_99_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_99_2, 2
    .p2align 3
Ltf_slots_99:
    .quad 0
Ltf_text_99_0:
    .byte 91
Ltf_text_99_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_100:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_100_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_100_2, 2
    .p2align 3
Ltf_slots_100:
    .quad 1
Ltf_text_100_0:
    .byte 91
Ltf_text_100_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_101:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_101_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_101_2, 2
    .p2align 3
Ltf_slots_101:
    .quad 255
Ltf_text_101_0:
    .byte 91
Ltf_text_101_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_102:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_102_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_102_2, 2
    .p2align 3
Ltf_slots_102:
    .quad -1
Ltf_text_102_0:
    .byte 91
Ltf_text_102_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_103:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_103_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_103_2, 2
    .p2align 3
Ltf_slots_103:
    .quad -9223372036854775808
Ltf_text_103_0:
    .byte 91
Ltf_text_103_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_104:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_104_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_104_2, 2
    .p2align 3
Ltf_slots_104:
    .quad 9223372036854775807
Ltf_text_104_0:
    .byte 91
Ltf_text_104_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_105:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_105_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_105_2, 2
    .p2align 3
Ltf_slots_105:
    .quad 3735928559
Ltf_text_105_0:
    .byte 91
Ltf_text_105_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_106:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_106_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_106_2, 2
    .p2align 3
Ltf_slots_106:
    .quad 16
Ltf_text_106_0:
    .byte 91
Ltf_text_106_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_107:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_107_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_107_2, 2
    .p2align 3
Ltf_slots_107:
    .quad 419385573
Ltf_text_107_0:
    .byte 91
Ltf_text_107_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_108:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_108_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_108_2, 2
    .p2align 3
Ltf_slots_108:
    .quad 0
Ltf_text_108_0:
    .byte 91
Ltf_text_108_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_109:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_109_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_109_2, 2
    .p2align 3
Ltf_slots_109:
    .quad 1
Ltf_text_109_0:
    .byte 91
Ltf_text_109_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_110:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_110_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_110_2, 2
    .p2align 3
Ltf_slots_110:
    .quad 255
Ltf_text_110_0:
    .byte 91
Ltf_text_110_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_111:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_111_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_111_2, 2
    .p2align 3
Ltf_slots_111:
    .quad -1
Ltf_text_111_0:
    .byte 91
Ltf_text_111_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_112:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_112_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_112_2, 2
    .p2align 3
Ltf_slots_112:
    .quad -9223372036854775808
Ltf_text_112_0:
    .byte 91
Ltf_text_112_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_113:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_113_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_113_2, 2
    .p2align 3
Ltf_slots_113:
    .quad 9223372036854775807
Ltf_text_113_0:
    .byte 91
Ltf_text_113_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_114:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_114_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_114_2, 2
    .p2align 3
Ltf_slots_114:
    .quad 3735928559
Ltf_text_114_0:
    .byte 91
Ltf_text_114_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_115:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_115_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_115_2, 2
    .p2align 3
Ltf_slots_115:
    .quad 16
Ltf_text_115_0:
    .byte 91
Ltf_text_115_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_116:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_116_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_116_2, 2
    .p2align 3
Ltf_slots_116:
    .quad 419385573
Ltf_text_116_0:
    .byte 91
Ltf_text_116_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_117:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_117_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_117_2, 2
    .p2align 3
Ltf_slots_117:
    .quad 0
Ltf_text_117_0:
    .byte 91
Ltf_text_117_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_118:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_118_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_118_2, 2
    .p2align 3
Ltf_slots_118:
    .quad 1
Ltf_text_118_0:
    .byte 91
Ltf_text_118_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_119:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_119_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_119_2, 2
    .p2align 3
Ltf_slots_119:
    .quad 255
Ltf_text_119_0:
    .byte 91
Ltf_text_119_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_120:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_120_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_120_2, 2
    .p2align 3
Ltf_slots_120:
    .quad -1
Ltf_text_120_0:
    .byte 91
Ltf_text_120_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_121:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_121_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_121_2, 2
    .p2align 3
Ltf_slots_121:
    .quad -9223372036854775808
Ltf_text_121_0:
    .byte 91
Ltf_text_121_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_122:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_122_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_122_2, 2
    .p2align 3
Ltf_slots_122:
    .quad 9223372036854775807
Ltf_text_122_0:
    .byte 91
Ltf_text_122_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_123:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_123_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_123_2, 2
    .p2align 3
Ltf_slots_123:
    .quad 3735928559
Ltf_text_123_0:
    .byte 91
Ltf_text_123_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_124:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_124_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_124_2, 2
    .p2align 3
Ltf_slots_124:
    .quad 16
Ltf_text_124_0:
    .byte 91
Ltf_text_124_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_125:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_125_0, 1
    .byte SEA_FPK_CONV, 'x', 1, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_125_2, 2
    .p2align 3
Ltf_slots_125:
    .quad 419385573
Ltf_text_125_0:
    .byte 91
Ltf_text_125_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_126:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_126_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_126_2, 2
    .p2align 3
Ltf_slots_126:
    .quad 0
Ltf_text_126_0:
    .byte 91
Ltf_text_126_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_127:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_127_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_127_2, 2
    .p2align 3
Ltf_slots_127:
    .quad 1
Ltf_text_127_0:
    .byte 91
Ltf_text_127_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_128:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_128_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_128_2, 2
    .p2align 3
Ltf_slots_128:
    .quad 255
Ltf_text_128_0:
    .byte 91
Ltf_text_128_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_129:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_129_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_129_2, 2
    .p2align 3
Ltf_slots_129:
    .quad -1
Ltf_text_129_0:
    .byte 91
Ltf_text_129_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_130:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_130_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_130_2, 2
    .p2align 3
Ltf_slots_130:
    .quad -9223372036854775808
Ltf_text_130_0:
    .byte 91
Ltf_text_130_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_131:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_131_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_131_2, 2
    .p2align 3
Ltf_slots_131:
    .quad 9223372036854775807
Ltf_text_131_0:
    .byte 91
Ltf_text_131_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_132:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_132_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_132_2, 2
    .p2align 3
Ltf_slots_132:
    .quad 3735928559
Ltf_text_132_0:
    .byte 91
Ltf_text_132_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_133:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_133_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_133_2, 2
    .p2align 3
Ltf_slots_133:
    .quad 16
Ltf_text_133_0:
    .byte 91
Ltf_text_133_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_134:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_134_0, 1
    .byte SEA_FPK_CONV, 'x', 8, SEA_CLS_I
    .long 8, 3, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_134_2, 2
    .p2align 3
Ltf_slots_134:
    .quad 419385573
Ltf_text_134_0:
    .byte 91
Ltf_text_134_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_135:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_135_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_135_2, 2
    .p2align 3
Ltf_slots_135:
    .quad 0
Ltf_text_135_0:
    .byte 91
Ltf_text_135_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_136:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_136_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_136_2, 2
    .p2align 3
Ltf_slots_136:
    .quad 1
Ltf_text_136_0:
    .byte 91
Ltf_text_136_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_137:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_137_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_137_2, 2
    .p2align 3
Ltf_slots_137:
    .quad 255
Ltf_text_137_0:
    .byte 91
Ltf_text_137_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_138:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_138_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_138_2, 2
    .p2align 3
Ltf_slots_138:
    .quad -1
Ltf_text_138_0:
    .byte 91
Ltf_text_138_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_139:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_139_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_139_2, 2
    .p2align 3
Ltf_slots_139:
    .quad -9223372036854775808
Ltf_text_139_0:
    .byte 91
Ltf_text_139_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_140:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_140_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_140_2, 2
    .p2align 3
Ltf_slots_140:
    .quad 9223372036854775807
Ltf_text_140_0:
    .byte 91
Ltf_text_140_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_141:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_141_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_141_2, 2
    .p2align 3
Ltf_slots_141:
    .quad 3735928559
Ltf_text_141_0:
    .byte 91
Ltf_text_141_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_142:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_142_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_142_2, 2
    .p2align 3
Ltf_slots_142:
    .quad 16
Ltf_text_142_0:
    .byte 91
Ltf_text_142_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_143:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_143_0, 1
    .byte SEA_FPK_CONV, 'x', 16, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_143_2, 2
    .p2align 3
Ltf_slots_143:
    .quad 419385573
Ltf_text_143_0:
    .byte 91
Ltf_text_143_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_144:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_144_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_144_2, 2
    .p2align 3
Ltf_slots_144:
    .quad 0
Ltf_text_144_0:
    .byte 91
Ltf_text_144_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_145:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_145_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_145_2, 2
    .p2align 3
Ltf_slots_145:
    .quad 1
Ltf_text_145_0:
    .byte 91
Ltf_text_145_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_146:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_146_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_146_2, 2
    .p2align 3
Ltf_slots_146:
    .quad 255
Ltf_text_146_0:
    .byte 91
Ltf_text_146_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_147:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_147_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_147_2, 2
    .p2align 3
Ltf_slots_147:
    .quad -1
Ltf_text_147_0:
    .byte 91
Ltf_text_147_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_148:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_148_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_148_2, 2
    .p2align 3
Ltf_slots_148:
    .quad -9223372036854775808
Ltf_text_148_0:
    .byte 91
Ltf_text_148_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_149:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_149_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_149_2, 2
    .p2align 3
Ltf_slots_149:
    .quad 9223372036854775807
Ltf_text_149_0:
    .byte 91
Ltf_text_149_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_150:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_150_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_150_2, 2
    .p2align 3
Ltf_slots_150:
    .quad 3735928559
Ltf_text_150_0:
    .byte 91
Ltf_text_150_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_151:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_151_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_151_2, 2
    .p2align 3
Ltf_slots_151:
    .quad 16
Ltf_text_151_0:
    .byte 91
Ltf_text_151_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_152:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_152_0, 1
    .byte SEA_FPK_CONV, 'x', 17, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_152_2, 2
    .p2align 3
Ltf_slots_152:
    .quad 419385573
Ltf_text_152_0:
    .byte 91
Ltf_text_152_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_153:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_153_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_153_2, 2
    .p2align 3
Ltf_slots_153:
    .quad 0
Ltf_text_153_0:
    .byte 91
Ltf_text_153_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_154:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_154_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_154_2, 2
    .p2align 3
Ltf_slots_154:
    .quad 1
Ltf_text_154_0:
    .byte 91
Ltf_text_154_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_155:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_155_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_155_2, 2
    .p2align 3
Ltf_slots_155:
    .quad 255
Ltf_text_155_0:
    .byte 91
Ltf_text_155_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_156:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_156_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_156_2, 2
    .p2align 3
Ltf_slots_156:
    .quad -1
Ltf_text_156_0:
    .byte 91
Ltf_text_156_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_157:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_157_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_157_2, 2
    .p2align 3
Ltf_slots_157:
    .quad -9223372036854775808
Ltf_text_157_0:
    .byte 91
Ltf_text_157_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_158:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_158_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_158_2, 2
    .p2align 3
Ltf_slots_158:
    .quad 9223372036854775807
Ltf_text_158_0:
    .byte 91
Ltf_text_158_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_159:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_159_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_159_2, 2
    .p2align 3
Ltf_slots_159:
    .quad 3735928559
Ltf_text_159_0:
    .byte 91
Ltf_text_159_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_160:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_160_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_160_2, 2
    .p2align 3
Ltf_slots_160:
    .quad 16
Ltf_text_160_0:
    .byte 91
Ltf_text_160_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_161:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_161_0, 1
    .byte SEA_FPK_CONV, 'x', 24, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_161_2, 2
    .p2align 3
Ltf_slots_161:
    .quad 419385573
Ltf_text_161_0:
    .byte 91
Ltf_text_161_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_162:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_162_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_162_2, 2
    .p2align 3
Ltf_slots_162:
    .quad 0
Ltf_text_162_0:
    .byte 91
Ltf_text_162_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_163:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_163_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_163_2, 2
    .p2align 3
Ltf_slots_163:
    .quad 1
Ltf_text_163_0:
    .byte 91
Ltf_text_163_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_164:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_164_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_164_2, 2
    .p2align 3
Ltf_slots_164:
    .quad 255
Ltf_text_164_0:
    .byte 91
Ltf_text_164_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_165:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_165_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_165_2, 2
    .p2align 3
Ltf_slots_165:
    .quad -1
Ltf_text_165_0:
    .byte 91
Ltf_text_165_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_166:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_166_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_166_2, 2
    .p2align 3
Ltf_slots_166:
    .quad -9223372036854775808
Ltf_text_166_0:
    .byte 91
Ltf_text_166_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_167:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_167_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_167_2, 2
    .p2align 3
Ltf_slots_167:
    .quad 9223372036854775807
Ltf_text_167_0:
    .byte 91
Ltf_text_167_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_168:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_168_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_168_2, 2
    .p2align 3
Ltf_slots_168:
    .quad 3735928559
Ltf_text_168_0:
    .byte 91
Ltf_text_168_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_169:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_169_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_169_2, 2
    .p2align 3
Ltf_slots_169:
    .quad 16
Ltf_text_169_0:
    .byte 91
Ltf_text_169_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_170:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_170_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long 12, 4, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_170_2, 2
    .p2align 3
Ltf_slots_170:
    .quad 419385573
Ltf_text_170_0:
    .byte 91
Ltf_text_170_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_171:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_171_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_171_2, 2
    .p2align 3
Ltf_slots_171:
    .quad 0
Ltf_text_171_0:
    .byte 91
Ltf_text_171_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_172:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_172_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_172_2, 2
    .p2align 3
Ltf_slots_172:
    .quad 1
Ltf_text_172_0:
    .byte 91
Ltf_text_172_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_173:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_173_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_173_2, 2
    .p2align 3
Ltf_slots_173:
    .quad 255
Ltf_text_173_0:
    .byte 91
Ltf_text_173_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_174:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_174_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_174_2, 2
    .p2align 3
Ltf_slots_174:
    .quad -1
Ltf_text_174_0:
    .byte 91
Ltf_text_174_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_175:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_175_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_175_2, 2
    .p2align 3
Ltf_slots_175:
    .quad -9223372036854775808
Ltf_text_175_0:
    .byte 91
Ltf_text_175_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_176:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_176_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_176_2, 2
    .p2align 3
Ltf_slots_176:
    .quad 9223372036854775807
Ltf_text_176_0:
    .byte 91
Ltf_text_176_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_177:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_177_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_177_2, 2
    .p2align 3
Ltf_slots_177:
    .quad 3735928559
Ltf_text_177_0:
    .byte 91
Ltf_text_177_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_178:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_178_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_178_2, 2
    .p2align 3
Ltf_slots_178:
    .quad 16
Ltf_text_178_0:
    .byte 91
Ltf_text_178_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_179:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_179_0, 1
    .byte SEA_FPK_CONV, 'x', 2, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_179_2, 2
    .p2align 3
Ltf_slots_179:
    .quad 419385573
Ltf_text_179_0:
    .byte 91
Ltf_text_179_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_180:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_180_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_180_2, 2
    .p2align 3
Ltf_slots_180:
    .quad 0
Ltf_text_180_0:
    .byte 91
Ltf_text_180_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_181:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_181_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_181_2, 2
    .p2align 3
Ltf_slots_181:
    .quad 1
Ltf_text_181_0:
    .byte 91
Ltf_text_181_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_182:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_182_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_182_2, 2
    .p2align 3
Ltf_slots_182:
    .quad 255
Ltf_text_182_0:
    .byte 91
Ltf_text_182_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_183:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_183_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_183_2, 2
    .p2align 3
Ltf_slots_183:
    .quad -1
Ltf_text_183_0:
    .byte 91
Ltf_text_183_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_184:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_184_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_184_2, 2
    .p2align 3
Ltf_slots_184:
    .quad -9223372036854775808
Ltf_text_184_0:
    .byte 91
Ltf_text_184_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_185:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_185_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_185_2, 2
    .p2align 3
Ltf_slots_185:
    .quad 9223372036854775807
Ltf_text_185_0:
    .byte 91
Ltf_text_185_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_186:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_186_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_186_2, 2
    .p2align 3
Ltf_slots_186:
    .quad 3735928559
Ltf_text_186_0:
    .byte 91
Ltf_text_186_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_187:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_187_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_187_2, 2
    .p2align 3
Ltf_slots_187:
    .quad 16
Ltf_text_187_0:
    .byte 91
Ltf_text_187_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_188:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_188_0, 1
    .byte SEA_FPK_CONV, 'x', 4, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_188_2, 2
    .p2align 3
Ltf_slots_188:
    .quad 419385573
Ltf_text_188_0:
    .byte 91
Ltf_text_188_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_189:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_189_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_189_2, 2
    .p2align 3
Ltf_slots_189:
    .quad 0
Ltf_text_189_0:
    .byte 91
Ltf_text_189_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_190:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_190_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_190_2, 2
    .p2align 3
Ltf_slots_190:
    .quad 1
Ltf_text_190_0:
    .byte 91
Ltf_text_190_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_191:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_191_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_191_2, 2
    .p2align 3
Ltf_slots_191:
    .quad 255
Ltf_text_191_0:
    .byte 91
Ltf_text_191_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_192:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_192_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_192_2, 2
    .p2align 3
Ltf_slots_192:
    .quad -1
Ltf_text_192_0:
    .byte 91
Ltf_text_192_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_193:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_193_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_193_2, 2
    .p2align 3
Ltf_slots_193:
    .quad -9223372036854775808
Ltf_text_193_0:
    .byte 91
Ltf_text_193_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_194:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_194_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_194_2, 2
    .p2align 3
Ltf_slots_194:
    .quad 9223372036854775807
Ltf_text_194_0:
    .byte 91
Ltf_text_194_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_195:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_195_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_195_2, 2
    .p2align 3
Ltf_slots_195:
    .quad 3735928559
Ltf_text_195_0:
    .byte 91
Ltf_text_195_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_196:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_196_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_196_2, 2
    .p2align 3
Ltf_slots_196:
    .quad 16
Ltf_text_196_0:
    .byte 91
Ltf_text_196_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_197:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_197_0, 1
    .byte SEA_FPK_CONV, 'X', 10, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_197_2, 2
    .p2align 3
Ltf_slots_197:
    .quad 419385573
Ltf_text_197_0:
    .byte 91
Ltf_text_197_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_198:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_198_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_198_2, 2
    .p2align 3
Ltf_slots_198:
    .quad 0
Ltf_text_198_0:
    .byte 91
Ltf_text_198_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_199:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_199_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_199_2, 2
    .p2align 3
Ltf_slots_199:
    .quad 1
Ltf_text_199_0:
    .byte 91
Ltf_text_199_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_200:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_200_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_200_2, 2
    .p2align 3
Ltf_slots_200:
    .quad 255
Ltf_text_200_0:
    .byte 91
Ltf_text_200_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_201:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_201_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_201_2, 2
    .p2align 3
Ltf_slots_201:
    .quad -1
Ltf_text_201_0:
    .byte 91
Ltf_text_201_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_202:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_202_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_202_2, 2
    .p2align 3
Ltf_slots_202:
    .quad -9223372036854775808
Ltf_text_202_0:
    .byte 91
Ltf_text_202_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_203:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_203_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_203_2, 2
    .p2align 3
Ltf_slots_203:
    .quad 9223372036854775807
Ltf_text_203_0:
    .byte 91
Ltf_text_203_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_204:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_204_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_204_2, 2
    .p2align 3
Ltf_slots_204:
    .quad 3735928559
Ltf_text_204_0:
    .byte 91
Ltf_text_204_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_205:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_205_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_205_2, 2
    .p2align 3
Ltf_slots_205:
    .quad 16
Ltf_text_205_0:
    .byte 91
Ltf_text_205_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_206:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_206_0, 1
    .byte SEA_FPK_CONV, 'x', 3, SEA_CLS_I
    .long 8, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_206_2, 2
    .p2align 3
Ltf_slots_206:
    .quad 419385573
Ltf_text_206_0:
    .byte 91
Ltf_text_206_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_207:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_207_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_207_2, 2
    .p2align 3
Ltf_slots_207:
    .quad 0
Ltf_text_207_0:
    .byte 91
Ltf_text_207_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_208:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_208_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_208_2, 2
    .p2align 3
Ltf_slots_208:
    .quad 1
Ltf_text_208_0:
    .byte 91
Ltf_text_208_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_209:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_209_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_209_2, 2
    .p2align 3
Ltf_slots_209:
    .quad 255
Ltf_text_209_0:
    .byte 91
Ltf_text_209_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_210:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_210_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_210_2, 2
    .p2align 3
Ltf_slots_210:
    .quad -1
Ltf_text_210_0:
    .byte 91
Ltf_text_210_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_211:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_211_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_211_2, 2
    .p2align 3
Ltf_slots_211:
    .quad -9223372036854775808
Ltf_text_211_0:
    .byte 91
Ltf_text_211_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_212:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_212_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_212_2, 2
    .p2align 3
Ltf_slots_212:
    .quad 9223372036854775807
Ltf_text_212_0:
    .byte 91
Ltf_text_212_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_213:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_213_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_213_2, 2
    .p2align 3
Ltf_slots_213:
    .quad 3735928559
Ltf_text_213_0:
    .byte 91
Ltf_text_213_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_214:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_214_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_214_2, 2
    .p2align 3
Ltf_slots_214:
    .quad 16
Ltf_text_214_0:
    .byte 91
Ltf_text_214_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_215:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_215_0, 1
    .byte SEA_FPK_CONV, 'x', 18, SEA_CLS_I
    .long -1, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_215_2, 2
    .p2align 3
Ltf_slots_215:
    .quad 419385573
Ltf_text_215_0:
    .byte 91
Ltf_text_215_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_216:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_216_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_216_2, 2
    .p2align 3
Ltf_slots_216:
    .quad 0
Ltf_text_216_0:
    .byte 91
Ltf_text_216_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_217:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_217_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_217_2, 2
    .p2align 3
Ltf_slots_217:
    .quad 1
Ltf_text_217_0:
    .byte 91
Ltf_text_217_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_218:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_218_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_218_2, 2
    .p2align 3
Ltf_slots_218:
    .quad 255
Ltf_text_218_0:
    .byte 91
Ltf_text_218_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_219:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_219_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_219_2, 2
    .p2align 3
Ltf_slots_219:
    .quad -1
Ltf_text_219_0:
    .byte 91
Ltf_text_219_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_220:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_220_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_220_2, 2
    .p2align 3
Ltf_slots_220:
    .quad -9223372036854775808
Ltf_text_220_0:
    .byte 91
Ltf_text_220_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_221:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_221_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_221_2, 2
    .p2align 3
Ltf_slots_221:
    .quad 9223372036854775807
Ltf_text_221_0:
    .byte 91
Ltf_text_221_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_222:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_222_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_222_2, 2
    .p2align 3
Ltf_slots_222:
    .quad 3735928559
Ltf_text_222_0:
    .byte 91
Ltf_text_222_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_223:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_223_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_223_2, 2
    .p2align 3
Ltf_slots_223:
    .quad 16
Ltf_text_223_0:
    .byte 91
Ltf_text_223_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_224:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_224_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_224_2, 2
    .p2align 3
Ltf_slots_224:
    .quad 419385573
Ltf_text_224_0:
    .byte 91
Ltf_text_224_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_225:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_225_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_225_2, 2
    .p2align 3
Ltf_slots_225:
    .quad 0
Ltf_text_225_0:
    .byte 91
Ltf_text_225_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_226:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_226_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_226_2, 2
    .p2align 3
Ltf_slots_226:
    .quad 1
Ltf_text_226_0:
    .byte 91
Ltf_text_226_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_227:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_227_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_227_2, 2
    .p2align 3
Ltf_slots_227:
    .quad 255
Ltf_text_227_0:
    .byte 91
Ltf_text_227_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_228:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_228_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_228_2, 2
    .p2align 3
Ltf_slots_228:
    .quad -1
Ltf_text_228_0:
    .byte 91
Ltf_text_228_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_229:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_229_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_229_2, 2
    .p2align 3
Ltf_slots_229:
    .quad -9223372036854775808
Ltf_text_229_0:
    .byte 91
Ltf_text_229_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_230:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_230_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_230_2, 2
    .p2align 3
Ltf_slots_230:
    .quad 9223372036854775807
Ltf_text_230_0:
    .byte 91
Ltf_text_230_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_231:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_231_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_231_2, 2
    .p2align 3
Ltf_slots_231:
    .quad 3735928559
Ltf_text_231_0:
    .byte 91
Ltf_text_231_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_232:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_232_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_232_2, 2
    .p2align 3
Ltf_slots_232:
    .quad 16
Ltf_text_232_0:
    .byte 91
Ltf_text_232_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_233:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_233_0, 1
    .byte SEA_FPK_CONV, 'X', 8, SEA_CLS_I
    .long 20, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_233_2, 2
    .p2align 3
Ltf_slots_233:
    .quad 419385573
Ltf_text_233_0:
    .byte 91
Ltf_text_233_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_234:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_234_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_234_2, 2
    .p2align 3
Ltf_slots_234:
    .quad 0
Ltf_text_234_0:
    .byte 91
Ltf_text_234_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_235:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_235_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_235_2, 2
    .p2align 3
Ltf_slots_235:
    .quad 1
Ltf_text_235_0:
    .byte 91
Ltf_text_235_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_236:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_236_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_236_2, 2
    .p2align 3
Ltf_slots_236:
    .quad 255
Ltf_text_236_0:
    .byte 91
Ltf_text_236_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_237:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_237_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_237_2, 2
    .p2align 3
Ltf_slots_237:
    .quad -1
Ltf_text_237_0:
    .byte 91
Ltf_text_237_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_238:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_238_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_238_2, 2
    .p2align 3
Ltf_slots_238:
    .quad -9223372036854775808
Ltf_text_238_0:
    .byte 91
Ltf_text_238_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_239:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_239_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_239_2, 2
    .p2align 3
Ltf_slots_239:
    .quad 9223372036854775807
Ltf_text_239_0:
    .byte 91
Ltf_text_239_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_240:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_240_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_240_2, 2
    .p2align 3
Ltf_slots_240:
    .quad 3735928559
Ltf_text_240_0:
    .byte 91
Ltf_text_240_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_241:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_241_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_241_2, 2
    .p2align 3
Ltf_slots_241:
    .quad 16
Ltf_text_241_0:
    .byte 91
Ltf_text_241_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_242:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_242_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 16, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_242_2, 2
    .p2align 3
Ltf_slots_242:
    .quad 419385573
Ltf_text_242_0:
    .byte 91
Ltf_text_242_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_243:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_243_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_243_2, 2
    .p2align 3
Ltf_slots_243:
    .quad 0
Ltf_text_243_0:
    .byte 91
Ltf_text_243_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_244:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_244_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_244_2, 2
    .p2align 3
Ltf_slots_244:
    .quad 1
Ltf_text_244_0:
    .byte 91
Ltf_text_244_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_245:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_245_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_245_2, 2
    .p2align 3
Ltf_slots_245:
    .quad 255
Ltf_text_245_0:
    .byte 91
Ltf_text_245_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_246:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_246_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_246_2, 2
    .p2align 3
Ltf_slots_246:
    .quad -1
Ltf_text_246_0:
    .byte 91
Ltf_text_246_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_247:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_247_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_247_2, 2
    .p2align 3
Ltf_slots_247:
    .quad -9223372036854775808
Ltf_text_247_0:
    .byte 91
Ltf_text_247_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_248:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_248_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_248_2, 2
    .p2align 3
Ltf_slots_248:
    .quad 9223372036854775807
Ltf_text_248_0:
    .byte 91
Ltf_text_248_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_249:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_249_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_249_2, 2
    .p2align 3
Ltf_slots_249:
    .quad 3735928559
Ltf_text_249_0:
    .byte 91
Ltf_text_249_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_250:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_250_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_250_2, 2
    .p2align 3
Ltf_slots_250:
    .quad 16
Ltf_text_250_0:
    .byte 91
Ltf_text_250_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_251:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_251_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_251_2, 2
    .p2align 3
Ltf_slots_251:
    .quad 419385573
Ltf_text_251_0:
    .byte 91
Ltf_text_251_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_252:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_252_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_252_2, 2
    .p2align 3
Ltf_slots_252:
    .quad 0
Ltf_text_252_0:
    .byte 91
Ltf_text_252_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_253:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_253_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_253_2, 2
    .p2align 3
Ltf_slots_253:
    .quad 1
Ltf_text_253_0:
    .byte 91
Ltf_text_253_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_254:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_254_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_254_2, 2
    .p2align 3
Ltf_slots_254:
    .quad 255
Ltf_text_254_0:
    .byte 91
Ltf_text_254_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_255:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_255_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_255_2, 2
    .p2align 3
Ltf_slots_255:
    .quad -1
Ltf_text_255_0:
    .byte 91
Ltf_text_255_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_256:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_256_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_256_2, 2
    .p2align 3
Ltf_slots_256:
    .quad -9223372036854775808
Ltf_text_256_0:
    .byte 91
Ltf_text_256_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_257:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_257_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_257_2, 2
    .p2align 3
Ltf_slots_257:
    .quad 9223372036854775807
Ltf_text_257_0:
    .byte 91
Ltf_text_257_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_258:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_258_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_258_2, 2
    .p2align 3
Ltf_slots_258:
    .quad 3735928559
Ltf_text_258_0:
    .byte 91
Ltf_text_258_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_259:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_259_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_259_2, 2
    .p2align 3
Ltf_slots_259:
    .quad 16
Ltf_text_259_0:
    .byte 91
Ltf_text_259_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_260:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_260_0, 1
    .byte SEA_FPK_CONV, 'X', 16, SEA_CLS_I
    .long -1, 20, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_260_2, 2
    .p2align 3
Ltf_slots_260:
    .quad 419385573
Ltf_text_260_0:
    .byte 91
Ltf_text_260_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_261:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_261_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_261_2, 2
    .p2align 3
Ltf_slots_261:
    .quad 0
Ltf_text_261_0:
    .byte 91
Ltf_text_261_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_262:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_262_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_262_2, 2
    .p2align 3
Ltf_slots_262:
    .quad 1
Ltf_text_262_0:
    .byte 91
Ltf_text_262_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_263:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_263_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_263_2, 2
    .p2align 3
Ltf_slots_263:
    .quad 255
Ltf_text_263_0:
    .byte 91
Ltf_text_263_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_264:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_264_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_264_2, 2
    .p2align 3
Ltf_slots_264:
    .quad -1
Ltf_text_264_0:
    .byte 91
Ltf_text_264_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_265:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_265_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_265_2, 2
    .p2align 3
Ltf_slots_265:
    .quad -9223372036854775808
Ltf_text_265_0:
    .byte 91
Ltf_text_265_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_266:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_266_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_266_2, 2
    .p2align 3
Ltf_slots_266:
    .quad 9223372036854775807
Ltf_text_266_0:
    .byte 91
Ltf_text_266_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_267:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_267_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_267_2, 2
    .p2align 3
Ltf_slots_267:
    .quad 3735928559
Ltf_text_267_0:
    .byte 91
Ltf_text_267_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_268:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_268_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_268_2, 2
    .p2align 3
Ltf_slots_268:
    .quad 16
Ltf_text_268_0:
    .byte 91
Ltf_text_268_2:
    .byte 93, 10
    .p2align 3
Ltf_fmt_269:
    .quad 3    // SEA_FMT_NPIECE
    .quad 1    // SEA_FMT_NCONV
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_269_0, 1
    .byte SEA_FPK_CONV, 'x', 0, SEA_CLS_I
    .long 2, -1, 0
    .quad 0, 0
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad Ltf_text_269_2, 2
    .p2align 3
Ltf_slots_269:
    .quad 419385573
Ltf_text_269_0:
    .byte 91
Ltf_text_269_2:
    .byte 93, 10
    .p2align 3

// The error-site table: one record per case.
    .globl _sea_sites
    .p2align 3
_sea_sites:
    .quad Ltf_sitefile, 1
    .quad Ltf_sitefile, 2
    .quad Ltf_sitefile, 3
    .quad Ltf_sitefile, 4
    .quad Ltf_sitefile, 5
    .quad Ltf_sitefile, 6
    .quad Ltf_sitefile, 7
    .quad Ltf_sitefile, 8
    .quad Ltf_sitefile, 9
    .quad Ltf_sitefile, 10
    .quad Ltf_sitefile, 11
    .quad Ltf_sitefile, 12
    .quad Ltf_sitefile, 13
    .quad Ltf_sitefile, 14
    .quad Ltf_sitefile, 15
    .quad Ltf_sitefile, 16
    .quad Ltf_sitefile, 17
    .quad Ltf_sitefile, 18
    .quad Ltf_sitefile, 19
    .quad Ltf_sitefile, 20
    .quad Ltf_sitefile, 21
    .quad Ltf_sitefile, 22
    .quad Ltf_sitefile, 23
    .quad Ltf_sitefile, 24
    .quad Ltf_sitefile, 25
    .quad Ltf_sitefile, 26
    .quad Ltf_sitefile, 27
    .quad Ltf_sitefile, 28
    .quad Ltf_sitefile, 29
    .quad Ltf_sitefile, 30
    .quad Ltf_sitefile, 31
    .quad Ltf_sitefile, 32
    .quad Ltf_sitefile, 33
    .quad Ltf_sitefile, 34
    .quad Ltf_sitefile, 35
    .quad Ltf_sitefile, 36
    .quad Ltf_sitefile, 37
    .quad Ltf_sitefile, 38
    .quad Ltf_sitefile, 39
    .quad Ltf_sitefile, 40
    .quad Ltf_sitefile, 41
    .quad Ltf_sitefile, 42
    .quad Ltf_sitefile, 43
    .quad Ltf_sitefile, 44
    .quad Ltf_sitefile, 45
    .quad Ltf_sitefile, 46
    .quad Ltf_sitefile, 47
    .quad Ltf_sitefile, 48
    .quad Ltf_sitefile, 49
    .quad Ltf_sitefile, 50
    .quad Ltf_sitefile, 51
    .quad Ltf_sitefile, 52
    .quad Ltf_sitefile, 53
    .quad Ltf_sitefile, 54
    .quad Ltf_sitefile, 55
    .quad Ltf_sitefile, 56
    .quad Ltf_sitefile, 57
    .quad Ltf_sitefile, 58
    .quad Ltf_sitefile, 59
    .quad Ltf_sitefile, 60
    .quad Ltf_sitefile, 61
    .quad Ltf_sitefile, 62
    .quad Ltf_sitefile, 63
    .quad Ltf_sitefile, 64
    .quad Ltf_sitefile, 65
    .quad Ltf_sitefile, 66
    .quad Ltf_sitefile, 67
    .quad Ltf_sitefile, 68
    .quad Ltf_sitefile, 69
    .quad Ltf_sitefile, 70
    .quad Ltf_sitefile, 71
    .quad Ltf_sitefile, 72
    .quad Ltf_sitefile, 73
    .quad Ltf_sitefile, 74
    .quad Ltf_sitefile, 75
    .quad Ltf_sitefile, 76
    .quad Ltf_sitefile, 77
    .quad Ltf_sitefile, 78
    .quad Ltf_sitefile, 79
    .quad Ltf_sitefile, 80
    .quad Ltf_sitefile, 81
    .quad Ltf_sitefile, 82
    .quad Ltf_sitefile, 83
    .quad Ltf_sitefile, 84
    .quad Ltf_sitefile, 85
    .quad Ltf_sitefile, 86
    .quad Ltf_sitefile, 87
    .quad Ltf_sitefile, 88
    .quad Ltf_sitefile, 89
    .quad Ltf_sitefile, 90
    .quad Ltf_sitefile, 91
    .quad Ltf_sitefile, 92
    .quad Ltf_sitefile, 93
    .quad Ltf_sitefile, 94
    .quad Ltf_sitefile, 95
    .quad Ltf_sitefile, 96
    .quad Ltf_sitefile, 97
    .quad Ltf_sitefile, 98
    .quad Ltf_sitefile, 99
    .quad Ltf_sitefile, 100
    .quad Ltf_sitefile, 101
    .quad Ltf_sitefile, 102
    .quad Ltf_sitefile, 103
    .quad Ltf_sitefile, 104
    .quad Ltf_sitefile, 105
    .quad Ltf_sitefile, 106
    .quad Ltf_sitefile, 107
    .quad Ltf_sitefile, 108
    .quad Ltf_sitefile, 109
    .quad Ltf_sitefile, 110
    .quad Ltf_sitefile, 111
    .quad Ltf_sitefile, 112
    .quad Ltf_sitefile, 113
    .quad Ltf_sitefile, 114
    .quad Ltf_sitefile, 115
    .quad Ltf_sitefile, 116
    .quad Ltf_sitefile, 117
    .quad Ltf_sitefile, 118
    .quad Ltf_sitefile, 119
    .quad Ltf_sitefile, 120
    .quad Ltf_sitefile, 121
    .quad Ltf_sitefile, 122
    .quad Ltf_sitefile, 123
    .quad Ltf_sitefile, 124
    .quad Ltf_sitefile, 125
    .quad Ltf_sitefile, 126
    .quad Ltf_sitefile, 127
    .quad Ltf_sitefile, 128
    .quad Ltf_sitefile, 129
    .quad Ltf_sitefile, 130
    .quad Ltf_sitefile, 131
    .quad Ltf_sitefile, 132
    .quad Ltf_sitefile, 133
    .quad Ltf_sitefile, 134
    .quad Ltf_sitefile, 135
    .quad Ltf_sitefile, 136
    .quad Ltf_sitefile, 137
    .quad Ltf_sitefile, 138
    .quad Ltf_sitefile, 139
    .quad Ltf_sitefile, 140
    .quad Ltf_sitefile, 141
    .quad Ltf_sitefile, 142
    .quad Ltf_sitefile, 143
    .quad Ltf_sitefile, 144
    .quad Ltf_sitefile, 145
    .quad Ltf_sitefile, 146
    .quad Ltf_sitefile, 147
    .quad Ltf_sitefile, 148
    .quad Ltf_sitefile, 149
    .quad Ltf_sitefile, 150
    .quad Ltf_sitefile, 151
    .quad Ltf_sitefile, 152
    .quad Ltf_sitefile, 153
    .quad Ltf_sitefile, 154
    .quad Ltf_sitefile, 155
    .quad Ltf_sitefile, 156
    .quad Ltf_sitefile, 157
    .quad Ltf_sitefile, 158
    .quad Ltf_sitefile, 159
    .quad Ltf_sitefile, 160
    .quad Ltf_sitefile, 161
    .quad Ltf_sitefile, 162
    .quad Ltf_sitefile, 163
    .quad Ltf_sitefile, 164
    .quad Ltf_sitefile, 165
    .quad Ltf_sitefile, 166
    .quad Ltf_sitefile, 167
    .quad Ltf_sitefile, 168
    .quad Ltf_sitefile, 169
    .quad Ltf_sitefile, 170
    .quad Ltf_sitefile, 171
    .quad Ltf_sitefile, 172
    .quad Ltf_sitefile, 173
    .quad Ltf_sitefile, 174
    .quad Ltf_sitefile, 175
    .quad Ltf_sitefile, 176
    .quad Ltf_sitefile, 177
    .quad Ltf_sitefile, 178
    .quad Ltf_sitefile, 179
    .quad Ltf_sitefile, 180
    .quad Ltf_sitefile, 181
    .quad Ltf_sitefile, 182
    .quad Ltf_sitefile, 183
    .quad Ltf_sitefile, 184
    .quad Ltf_sitefile, 185
    .quad Ltf_sitefile, 186
    .quad Ltf_sitefile, 187
    .quad Ltf_sitefile, 188
    .quad Ltf_sitefile, 189
    .quad Ltf_sitefile, 190
    .quad Ltf_sitefile, 191
    .quad Ltf_sitefile, 192
    .quad Ltf_sitefile, 193
    .quad Ltf_sitefile, 194
    .quad Ltf_sitefile, 195
    .quad Ltf_sitefile, 196
    .quad Ltf_sitefile, 197
    .quad Ltf_sitefile, 198
    .quad Ltf_sitefile, 199
    .quad Ltf_sitefile, 200
    .quad Ltf_sitefile, 201
    .quad Ltf_sitefile, 202
    .quad Ltf_sitefile, 203
    .quad Ltf_sitefile, 204
    .quad Ltf_sitefile, 205
    .quad Ltf_sitefile, 206
    .quad Ltf_sitefile, 207
    .quad Ltf_sitefile, 208
    .quad Ltf_sitefile, 209
    .quad Ltf_sitefile, 210
    .quad Ltf_sitefile, 211
    .quad Ltf_sitefile, 212
    .quad Ltf_sitefile, 213
    .quad Ltf_sitefile, 214
    .quad Ltf_sitefile, 215
    .quad Ltf_sitefile, 216
    .quad Ltf_sitefile, 217
    .quad Ltf_sitefile, 218
    .quad Ltf_sitefile, 219
    .quad Ltf_sitefile, 220
    .quad Ltf_sitefile, 221
    .quad Ltf_sitefile, 222
    .quad Ltf_sitefile, 223
    .quad Ltf_sitefile, 224
    .quad Ltf_sitefile, 225
    .quad Ltf_sitefile, 226
    .quad Ltf_sitefile, 227
    .quad Ltf_sitefile, 228
    .quad Ltf_sitefile, 229
    .quad Ltf_sitefile, 230
    .quad Ltf_sitefile, 231
    .quad Ltf_sitefile, 232
    .quad Ltf_sitefile, 233
    .quad Ltf_sitefile, 234
    .quad Ltf_sitefile, 235
    .quad Ltf_sitefile, 236
    .quad Ltf_sitefile, 237
    .quad Ltf_sitefile, 238
    .quad Ltf_sitefile, 239
    .quad Ltf_sitefile, 240
    .quad Ltf_sitefile, 241
    .quad Ltf_sitefile, 242
    .quad Ltf_sitefile, 243
    .quad Ltf_sitefile, 244
    .quad Ltf_sitefile, 245
    .quad Ltf_sitefile, 246
    .quad Ltf_sitefile, 247
    .quad Ltf_sitefile, 248
    .quad Ltf_sitefile, 249
    .quad Ltf_sitefile, 250
    .quad Ltf_sitefile, 251
    .quad Ltf_sitefile, 252
    .quad Ltf_sitefile, 253
    .quad Ltf_sitefile, 254
    .quad Ltf_sitefile, 255
    .quad Ltf_sitefile, 256
    .quad Ltf_sitefile, 257
    .quad Ltf_sitefile, 258
    .quad Ltf_sitefile, 259
    .quad Ltf_sitefile, 260
    .quad Ltf_sitefile, 261
    .quad Ltf_sitefile, 262
    .quad Ltf_sitefile, 263
    .quad Ltf_sitefile, 264
    .quad Ltf_sitefile, 265
    .quad Ltf_sitefile, 266
    .quad Ltf_sitefile, 267
    .quad Ltf_sitefile, 268
    .quad Ltf_sitefile, 269
    .quad Ltf_sitefile, 270
    .p2align 3
Ltf_sitefile:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR, 0, 0, 0, 0, 0, 0, 0
    .quad 12
    .byte 114,116,95,108,105,98,95,104,101,120,46,115
