/***********************************************************************
 * RISC-V CSR Simple Test (RV32, no traps, no C-preprocessor)
 *
 * - Runs in M-mode and records CSR values into `results`.
 * - Does NOT deliberately trigger traps/exceptions.
 * - Provides an optional Debug-mode probe (`debug_probe`) to capture
 *   dcsr/dpc/dscratch0; execute it only while in Debug Mode.
 *
 * Results (word offsets from `results`):
 *   [ 0] misa
 *   [ 1] mstatus (initial)
 *   [ 2] mstatus (after set MIE)
 *   [ 3] mstatus (after clear MIE)
 *   [ 4] mtvec (initial read)
 *   [ 5] mtvec (after write-back to label `vector_here`)
 *   [ 6] mepc  (snapshot without causing traps)
 *   [ 7] mcause (snapshot without causing traps)
 *   [ 8] mtval (snapshot without causing traps)
 *   [ 9] dcsr        (written by debug_probe only)
 *   [10] dpc         (written by debug_probe only)
 *   [11] dscratch0   (written by debug_probe only)
 *
 * Build example (RV32):
 *   riscv32-unknown-elf-gcc -nostartfiles -nostdlib -Wl,-T,linker.ld \
 *       -march=rv32imac -mabi=ilp32 -o csr_simple.elf csr_simple.S
 ***********************************************************************/

    .section .text
    .globl _start

_start:
    /* Set up a simple stack (optional) */
    la      sp, _stack_top

    /* Point gp at results base for compact addressing */
    la      gp, results

    /* --- misa --- */
    csrr    t0, misa
    sw      t0, 0(gp)          /* results[0] */

    /* --- mstatus: initial, set/clear MIE --- */
    csrr    t1, mstatus
    sw      t1, 4(gp)          /* results[1] */

    /* set MIE (bit 3) */
    li      t2, 0x8
    csrs    mstatus, t2
    csrr    t1, mstatus
    sw      t1, 8(gp)          /* results[2] */

    /* clear MIE */
    csrc    mstatus, t2
    csrr    t1, mstatus
    sw      t1, 12(gp)         /* results[3] */

    /* --- mtvec: read, then write & read-back --- */
    csrr    t3, mtvec
    sw      t3, 16(gp)         /* results[4] */

    la      t4, vector_here     /* some aligned label */
    csrw    mtvec, t4
    csrr    t5, mtvec
    sw      t5, 20(gp)         /* results[5] */

    /* --- snapshot mepc/mcause/mtval without taking traps --- */
    csrr    t6, mepc
    sw      t6, 24(gp)         /* results[6] */

    csrr    t6, mcause
    sw      t6, 28(gp)         /* results[7] */

    csrr    t6, mtval
    sw      t6, 32(gp)         /* results[8] */

halt:
    wfi
    j       halt

/* A harmless code location to point mtvec at */
    .align 4
vector_here:
    j       vector_here

/* ------------------------------------------------------------ */
/*            Debug-mode-only probe for debug CSRs              */
/*  Run this label while in Debug Mode to store dcsr/dpc/       */
/*  dscratch0 into results[9..11], then return with DRET.       */
/* ------------------------------------------------------------ */
    .align 4
    .globl debug_probe
debug_probe:
    la      t0, results
    csrr    t1, dcsr           /* requires Debug Mode */
    sw      t1, 36(t0)         /* results[9] */
    csrr    t2, dpc
    sw      t2, 40(t0)         /* results[10] */
    csrr    t3, dscratch0      /* if implemented */
    sw      t3, 44(t0)         /* results[11] */
    .word   0x7b200073         /* DRET (if assembler lacks mnemonic) */

/* ------------------------------------------------------------ */
/*                            DATA                              */
/* ------------------------------------------------------------ */
    .section .bss
    .align 8
    .globl results
results:
    .space  64                 /* 64 bytes for 16 words (more than enough) */

    .align 16
    .globl _stack
_stack:
    .space  1024
    .globl _stack_top
_stack_top:


