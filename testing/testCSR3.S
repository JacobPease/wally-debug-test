# riscvtestCSR.s
# Augmented DDCA version: adds CSR tests (mstatus/mtvec) before the original ALU/LD/ST/BR/JAL flow.
# Pass: mem[100] = 25
	# Fail: mem[100] = 0xFFFF_FFFF

# Sarah.Harris@unlv.edu
# David_Harris@hmc.edu
# james.stine@okstate.edu
# 26 August 2025
#

        .text	
        .globl main

main:
        # --- original setup ---
        addi x2, x0, 5           # x2 = 5
        addi x3, x0, 12          # x3 = 12 (used later for the mem[96] test)
        addi x7, x3, -9          # x7 = (12 - 9) = 3

# ---------------------------------------------
# CSR SELF-TEST (uses x10..x15 only; leaves x2,x3,x4,x5,x7 intact)
# Tests CSRRW/CSRRS/CSRRC and the immediate forms on mstatus, plus a simple mtvec write/read.
# ---------------------------------------------
csrtest:
        # Snapshot current mstatus (expected 0 after reset in your simple CSR impl)
        csrrs x10, mstatus, x0        # x10 = old mstatus (no modify)

        # 1) CSRRW: write pattern P1, check old/new
        li   x12, 0x00000088          # set bits 7 (MPIE) and 3 (MIE)
        csrrw x11, mstatus, x12       # x11 = old mstatus
        bne  x11, x10, fail
        csrrs x13, mstatus, x0        # x13 = new mstatus
        bne  x13, x12, fail

        # 2) CSRRS: set another bit (e.g., bit 11), expect OR result
        li   x14, (1 << 11)
        csrrs x0,  mstatus, x14       # set bit 11 (ignore read)
        csrrs x13, mstatus, x0        # read back
        li   x15, (0x00000088 | (1<<11))
        bne  x13, x15, fail

        # 3) CSRRC: clear bits 7 and 3; expect only bit 11 remains
        li   x12, 0x00000088
        csrrc x0,  mstatus, x12
        csrrs x13, mstatus, x0
        li   x15, (1<<11)
        bne  x13, x15, fail

        # 4) Immediate forms quick sanity:
        csrrwi x11, mstatus, 0        # write 0; x11 gets old (don’t care); now mstatus = 0
        csrrsi x13, mstatus, 0        # read-only (no modify)
        bne    x13, x0, fail

        # 5) mtvec write/read (aligned base, mode=0)
        li   x12, 0x00000100
        csrrw x11, mtvec, x12
        csrrs x13, mtvec, x0
        bne  x13, x12, fail

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	
done:   beq  x2, x2, done             # infinite loop

# ---------------------------------------------
# FAIL PATH: mark memory[100] = 0xFFFF_FFFF, then loop.
# ---------------------------------------------
fail:
        addi x2, x0, -1               # 0xFFFF_FFFF
        sw   x2, 100(x0)
1:      beq  x0, x0, 1b
