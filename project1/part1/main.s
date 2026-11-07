@ Fahrenheit Temperature Average, with Celsius Conversion
@
@ Averages the signed Fahrenheit word readings in TEMPS and stores the
@ average in AVERAGE (deg F) and AVERAGE_C (deg C). Celsius is computed from
@ the exact total, (total - 32*count) * 5 / (9*count), so it carries only one
@ truncation rather than compounding the Fahrenheit one.
@ The Cortex-A8 has no hardware divide, so division is repeated subtraction;
@ quotients truncate toward zero, as C's integer division does.
@ At the NOP breakpoint: R6 = total, R7 = count, R8 = deg F, R9 = deg C.
@
@ Uses R0-R9, LR
@
@ Bryan Borgeson
@ ECE371 - Microprocessors
@ 2026, November 7


.syntax unified
.global _start

.section .isr_vector, "ax"
.align 5                @ VBAR ignores bits [4:0]; holds if the .lds stops aligning .rsthand
__isr_vector:
    ldr pc, [pc, #24]   /* 0x00 Reset */
    ldr pc, [pc, #24]   /* 0x04 Undefined Instruction */
    ldr pc, [pc, #24]   /* 0x08 Supervisor Call (SVC) */
    ldr pc, [pc, #24]   /* 0x0C Prefetch Abort */
    ldr pc, [pc, #24]   /* 0x10 Data Abort */
    ldr pc, [pc, #24]   /* 0x14 Reserved */
    ldr pc, [pc, #24]   /* 0x18 IRQ */
    ldr pc, [pc, #24]   /* 0x1C FIQ */

    .long _start
    .long Undef_Handler
    .long SVC_Handler
    .long PABT_Handler
    .long DABT_Handler
    .long 0
    .long IRQ_Handler
    .long FIQ_Handler

.text
_start:
    /* Set Vector Base Address Register (VBAR) to our vector table */
    ldr r0, = __isr_vector
    mcr p15, 0, r0, c12, c0, 0

    ldr     r4, =TEMPS          @ r4 = pointer to current temp
    ldr     r5, =TEMPS_END      @ r5 = end of list
    mov     r6, #0              @ r6 = total
    mov     r7, #0              @ r7 = count

@ ---- WHILE (temps) DO ----
loop:
    cmp     r4, r5              @ any temps left?
    bhs     done_loop           @ no -> leave loop (unsigned: addresses)
    ldr     r0, [r4], #4        @ load temp, advance pointer
    add     r6, r6, r0          @ total += temp
    add     r7, r7, #1          @ count++
    b       loop
done_loop:

@ ---- DIVIDE total BY count ----
    mov     r0, r6              @ dividend = total
    mov     r1, r7              @ divisor = count
    bl      sdiv
    mov     r8, r0              @ r8 = average, deg F

@ ---- CONVERT to Celsius: (total - 32*count) * 5 / (9*count) ----
    sub     r0, r6, r7, lsl #5  @ r0 = total - 32*count
    add     r0, r0, r0, lsl #2  @ r0 = r0 * 5
    add     r1, r7, r7, lsl #3  @ r1 = 9*count
    bl      sdiv
    mov     r9, r0              @ r9 = average, deg C

    ldr     r0, =AVERAGE
    str     r8, [r0]            @ AVERAGE = average, deg F
    ldr     r0, =AVERAGE_C
    str     r9, [r0]            @ AVERAGE_C = average, deg C

    NOP                         @ Hardware breakpoint target instruction
    B .                         @ Trap after completion

@ sdiv: R0 = R0 / R1, truncated toward zero. R1 must be positive.
@ Clobbers R2, R3.
sdiv:
    mov     r2, #0              @ r2 = quotient
    mov     r3, #0              @ r3 = sign flag
    cmp     r0, #0              @ handle negative dividends
    rsblt   r0, r0, #0          @ r0 = |dividend|
    movlt   r3, #1
sdiv_loop:
    cmp     r0, r1              @ dividend >= divisor?
    blt     sdiv_done
    sub     r0, r0, r1          @ dividend -= divisor
    add     r2, r2, #1          @ quotient++
    b       sdiv_loop
sdiv_done:
    cmp     r3, #1              @ restore sign if dividend was negative
    rsbeq   r2, r2, #0
    mov     r0, r2
    bx      lr

Undef_Handler:
    b .
SVC_Handler:
    movs pc, lr
PABT_Handler:
    b .
DABT_Handler:
    b .
IRQ_Handler:
    b .
FIQ_Handler:
    b .

.data
TEMPS:      .word   72, 68, 75, 80, 77, 69, 71, 74  @ 16 temperature readings
            .word   70, 73, 76, 79, 66, 78, 72, 75
TEMPS_END:                                          @ end-of-list marker (after 16 words)
.if TEMPS_END == TEMPS          @ an empty list would hang sdiv_loop (count = 0)
.error "TEMPS is empty: the average needs at least one reading"
.endif
AVERAGE:    .word   0
AVERAGE_C:  .word   0
