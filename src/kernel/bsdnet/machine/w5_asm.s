;==============================================================================
; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
;
; w5_asm.s - the W5100's indirect bus, for net/if_w5.c.  X holds the slot in its
; high nibble for every chip access, so the same code runs in any slot with no
; patch table.  Entered with DBR on the data bank, where w5_slotx and w5_end are,
; and where every buffer passed here must be.  The kernel's bus state is reached
; by moving DBR to the live kernel bank, the bank its exports are relative to.
;
; The ISR skips the chip while _u2Locked is set, as net.mod's U2_LOCK arranges.
; w5_lock also drops IMR so a skipped interrupt cannot hold the line.
;==============================================================================
W5_MR0          EQU     $E0C084         ; slot 0's addresses; X adds the slot
W5_ARH0         EQU     $E0C085
W5_ARL0         EQU     $E0C086
W5_DAT0         EQU     $E0C087
W5_SLTROMSEL    EQU     $E0C02D

W5_KBANK        MAC
                PHB
                SEP     #$20
                MX      %10
                LDAL    SYS_KCALL+3
                PHA
                PLB
                <<<

; w5_init() - the card's slot, 0 for none.
w5_init         MX      %00
                W5_KBANK
                LDA     |_u2Slot
                PLB
                REP     #$20
                MX      %00
                AND     #$00FF
                PHA
                ASL
                ASL
                ASL
                ASL
                STA     |w5_slotx
                PLA
                RTL

; w5_claim0() - claim socket 0 from the kernel's allocator.  0, or 1 if it is held.
w5_claim0       MX      %00
                W5_KBANK
                LDA     |_w5SockInUse
                LSR
                BCS     @cl_busy
                LDA     |_w5SockInUse
                ORA     #$01
                STA     |_w5SockInUse
                PLB
                REP     #$20
                MX      %00
                LDA     #0
                RTL
@cl_busy        MX      %10
                PLB
                REP     #$20
                MX      %00
                LDA     #1
                RTL

w5_lock         MX      %00
                LDX     |w5_slotx
                PHP
                W5_KBANK
                SEI
                LDAL    W5_SLTROMSEL    ; firmware may have put the slot back
                ORA     |_u2SltBit
                STAL    W5_SLTROMSEL
                LDA     #1
                STA     |_u2Locked
                LDA     #0
                STAL    W5_ARH0,X
                LDA     #$16
                STAL    W5_ARL0,X
                LDA     #0
                STAL    W5_DAT0,X       ; IMR
                PLB
                REP     #$20
                MX      %00
                PLP
                RTL

w5_unlock       MX      %00
                LDX     |w5_slotx
                PHP
                W5_KBANK
                SEI
                LDA     #0
                STA     |_u2Locked
                STAL    W5_ARH0,X
                LDA     #$16
                STAL    W5_ARL0,X
                LDA     |_u2Imr
                STAL    W5_DAT0,X
                PLB
                REP     #$20
                MX      %00
                PLP
                RTL

; w5_arm() - under the lock: socket 0's interrupt back on at w5_unlock.
w5_arm          MX      %00
                W5_KBANK
                LDA     |_u2RxReady
                AND     #$FE
                STA     |_u2RxReady
                LDA     #1
                STA     |_u2Imr
                PLB
                REP     #$20
                MX      %00
                RTL

; w5_setpb() - MR's ping block: icmp_input answers pings, not the chip as well.
w5_setpb        MX      %00
                LDX     |w5_slotx
                SEP     #$20
                MX      %10
                LDAL    W5_MR0,X
                ORA     #$10
                STAL    W5_MR0,X
                REP     #$20
                MX      %00
                RTL

; A = reg: point the bus there.  Returns X = the slot.
w5_ar           MX      %00
                LDX     |w5_slotx
                SEP     #$20
                MX      %10
                XBA
                STAL    W5_ARH0,X
                XBA
                STAL    W5_ARL0,X
                REP     #$20
                MX      %00
                RTS

; w5_setar(reg) - point the bus at reg.  It then advances by itself.
w5_setar        MX      %00
                LDA     4,S
                JSR     w5_ar
                RTL

; w5_rreg(reg) - one byte.
w5_rreg         MX      %00
                LDA     4,S
                JSR     w5_ar
                SEP     #$20
                MX      %10
                LDAL    W5_DAT0,X
                REP     #$20
                MX      %00
                AND     #$00FF
                RTL

; w5_rreg16(reg) - a big-endian register pair.
w5_rreg16       MX      %00
                LDA     4,S
                JSR     w5_ar
                SEP     #$20
                MX      %10
                LDAL    W5_DAT0,X
                XBA
                LDAL    W5_DAT0,X
                REP     #$20
                MX      %00
                RTL

; w5_wreg(reg, val)
w5_wreg         MX      %00
                LDA     4,S
                JSR     w5_ar
                SEP     #$20
                MX      %10
                LDA     6,S
                STAL    W5_DAT0,X
                REP     #$20
                MX      %00
                RTL

; w5_wreg16(reg, val)
w5_wreg16       MX      %00
                LDA     4,S
                JSR     w5_ar
                SEP     #$20
                MX      %10
                LDA     7,S
                STAL    W5_DAT0,X
                LDA     6,S
                STAL    W5_DAT0,X
                REP     #$20
                MX      %00
                RTL

; w5_rxcopy(dst, n) - n bytes from the bus's current address, to the data bank.
; The caller splits a run at the ring's end and points the bus again.
w5_rxcopy       MX      %00
                LDA     8,S
                BEQ     @rx_done
                CLC
                ADC     4,S
                STA     |w5_end
                LDA     4,S
                TAY
                LDX     |w5_slotx
                SEP     #$20
                MX      %10
@rx_l           LDAL    W5_DAT0,X
                STA     |$0000,Y
                INY
                CPY     |w5_end
                BNE     @rx_l
                REP     #$20
                MX      %00
@rx_done        RTL

; w5_txcopy(src, n) - the other way.
w5_txcopy       MX      %00
                LDA     8,S
                BEQ     @tx_done
                CLC
                ADC     4,S
                STA     |w5_end
                LDA     4,S
                TAY
                LDX     |w5_slotx
                SEP     #$20
                MX      %10
@tx_l           LDA     |$0000,Y
                STAL    W5_DAT0,X
                INY
                CPY     |w5_end
                BNE     @tx_l
                REP     #$20
                MX      %00
@tx_done        RTL
