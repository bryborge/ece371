@ Fahrenheit Temperature Minimum and Maximum
@
@ Passes the address and length of the signed Fahrenheit word readings in
@ TEMPS to the minmax procedure, then stores the results it returns in
@ Fmin and Fmax.
@ At the NOP breakpoint: R0 = min, R1 = max.
@
@ Uses R0-R3, R12, LR
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

    ldr     r0, =TEMPS          @ r0 = array address
    ldr     r1, =NUM_TEMPS      @ r1 = number of values
    bl      minmax              @ returns r0 = min, r1 = max

    ldr     r2, =Fmin
    str     r0, [r2]            @ Fmin = min
    ldr     r2, =Fmax
    str     r1, [r2]            @ Fmax = max

    NOP                         @ Hardware breakpoint target instruction
    B .                         @ Trap after completion

@ minmax: find the smallest and largest signed words in an array.
@ In:  R0 = array address, R1 = number of words (must be at least 1)
@ Out: R0 = min, R1 = max
@ Clobbers R2, R3, R12.
minmax:
    ldr     r2, [r0], #4        @ r2 = min so far = first value
    mov     r3, r2              @ r3 = max so far = first value
minmax_loop:
    subs    r1, r1, #1          @ any values left?
    beq     minmax_done
    ldr     r12, [r0], #4       @ r12 = next value, advance pointer
    cmp     r12, r2
    movlt   r2, r12             @ new min (signed compare)
    cmp     r12, r3
    movgt   r3, r12             @ new max (signed compare)
    b       minmax_loop
minmax_done:
    mov     r0, r2
    mov     r1, r3
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
.equ NUM_TEMPS, (TEMPS_END - TEMPS) / 4
.if NUM_TEMPS == 0              @ minmax reads the first value unconditionally
.error "TEMPS is empty: min and max need at least one reading"
.endif
Fmin:       .word   0
Fmax:       .word   0
