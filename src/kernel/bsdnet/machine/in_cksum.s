;==============================================================================
; SPDX-License-Identifier: BSD-2-Clause
; SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
; FGX-Provenance: 2.11BSD usr/sys/pdp/in_cksum.c
;   Written for FGX after usr/sys/pdp/in_cksum.c, 2.11BSD.  Original work:
;   Copyright (c) 1986 Regents of the University of California.
;   All rights reserved.
;
; in_cksum(m, len) - the Internet checksum of len bytes of an mbuf chain.
;
; The ones' complement sum does not care about byte order as long as a word is
; read the same way throughout, so the little-endian words here sum to the same
; answer a big-endian machine gets, byte-swapped, which is what the header wants.
; A segment that ends on an odd byte leaves the next segment's first byte to be
; the high half of the word, as upstream's plen does.
;
; THE FRAME IS THE DIRECT PAGE.  D points at the stack for the routine's length:
; the [dp],Y long pointers then live on the stack, and no fcc register is touched.
;
;   1,2,3,4  ptr     the data, as a long pointer
;   5        sum
;   7        mlen    bytes of this mbuf still to sum
;   9        odd     nonzero: the last segment ended on an odd byte
;   11       saved D
;   13       return address, 3 bytes
;   16,18    m       the mbuf; advanced as the chain is walked
;   20       len
;==============================================================================
CK_L            EQU     10
CK_PTR          EQU     1
CK_SUM          EQU     5
CK_MLEN         EQU     7
CK_ODD          EQU     9
CK_M            EQU     16
CK_LEN          EQU     20
M_NEXT          EQU     0
M_OFF           EQU     4
M_LEN           EQU     6

in_cksum        MX      %00
                PHD
                TSC
                SEC
                SBC     #CK_L
                TCS
                TCD
                STZ     CK_SUM
                STZ     CK_ODD
@next           LDA     CK_LEN
                BNE     @more
@stop           BRL     @done
@more           LDA     CK_M+2
                AND     #$00FF          ; the bank; the byte above it is a pad
                ORA     CK_M
                BEQ     @stop           ; out of data: sum what there was
                LDY     #M_OFF
                LDA     [CK_M],Y
                CLC
                ADC     CK_M            ; within the bank, as mtod adds
                STA     CK_PTR
                LDA     CK_M+2
                STA     CK_PTR+2
                LDY     #M_LEN
                LDA     [CK_M],Y
                CMP     CK_LEN
                BCC     @short
                LDA     CK_LEN
@short          STA     CK_MLEN
                LDA     CK_LEN
                SEC
                SBC     CK_MLEN
                STA     CK_LEN
                LDA     CK_MLEN
                BEQ     @adv
                ; A byte owed from the last segment: this one's first byte is
                ; the high half of that word.
                LDA     CK_ODD
                BEQ     @even
                SEP     #$20
                MX      %10
                LDA     [CK_PTR]
                REP     #$20
                MX      %00
                AND     #$00FF
                XBA
                CLC
                ADC     CK_SUM
                ADC     #0
                STA     CK_SUM
                INC     CK_PTR
                DEC     CK_MLEN
                STZ     CK_ODD
@even           LDA     CK_MLEN
                LSR
                BEQ     @tail
                TAX                     ; X = words
                LDY     #0
                LDA     CK_SUM
                CLC
@word           ADC     [CK_PTR],Y      ; INY and DEX leave carry alone, so it
                INY                     ;   rolls into the next word
                INY
                DEX
                BNE     @word
                ADC     #0
                STA     CK_SUM
                BRA     @tail2
@tail           LDY     #0
@tail2          LDA     CK_MLEN
                AND     #1
                BEQ     @adv
                SEP     #$20
                MX      %10
                LDA     [CK_PTR],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                CLC
                ADC     CK_SUM
                ADC     #0
                STA     CK_SUM
                LDA     #1
                STA     CK_ODD
@adv            LDY     #M_NEXT+2
                LDA     [CK_M],Y
                TAX
                LDY     #M_NEXT
                LDA     [CK_M],Y
                STA     CK_M
                STX     CK_M+2
                BRL     @next
@done           LDA     CK_SUM
                EOR     #$FFFF
                TAY
                TSC
                CLC
                ADC     #CK_L
                TCS
                PLD
                TYA
                RTL
