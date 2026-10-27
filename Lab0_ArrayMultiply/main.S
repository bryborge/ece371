@ Array Multiply Program
@ Multiplies halfwords from MULTIPLICANDS by MULTIPLIERS
@ and stores results in PRODUCTS array.
@ Uses R1-R4, R6-R8
@ Douglas V. Hall / PSU ECE 371/372

.syntax unified
.text
.code 32
.global _start
.global NEXT
.global __isr_vector

.section .isr_vector, "ax"
.align 5
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
.align 2
_start:
    /* Initialize Supervisor stack pointer */
    ldr sp, = __stack

    /* Set Vector Base Address Register (VBAR) to our vector table */
    ldr r0, = __isr_vector
    mcr p15, 0, r0, c12, c0, 0

    .equ NUM, 4
    LDR R1, =MULTIPLICANDS      @ Load pointer to MULTIPLICANDS array
    LDR R2, =MULTIPLIERS        @ Load pointer to MULTIPLIERS array
    LDR R3, =PRODUCTS           @ Load pointer to PRODUCTS array
    MOV R4, #NUM                @ Initialize loop counter

NEXT:
    LDRH R6, [R1]               @ Load MULTIPLICAND halfword into R6
    LDRH R7, [R2]               @ Load MULTIPLIER halfword into R7
    MUL R8, R6, R7              @ Multiply halfwords
    STR R8, [R3]                @ Store product in PRODUCTS array
    ADD R1, R1, #2              @ Increment MULTIPLICAND pointer
    ADD R2, R2, #2              @ Increment MULTIPLIER pointer
    ADD R3, R3, #4              @ Increment PRODUCTS pointer
    SUBS R4, R4, #1             @ Decrement loop counter
    BNE NEXT                    @ Branch if loop counter != 0
    NOP                         @ Hardware breakpoint target instruction
    B .                         @ Trap after completion

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
MULTIPLICANDS:  .HWORD 0x1111, 0x2222, 0x3333, 0x4444
MULTIPLIERS:    .HWORD 0x1111, 0x2222, 0x3333, 0x4444
PRODUCTS:       .WORD  0x0, 0x0, 0x0, 0x0
