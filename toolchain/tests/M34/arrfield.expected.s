                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrfield.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #main_FRAMESIZE
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #gs+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #gs+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gs+8
                STA     _fcc_long_hi
                LDA     gs+6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _arrfield_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_arrfield_L0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     #gs+14
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #16384
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dtof
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gs+24
                STA     _fcc_long_hi
                LDA     gs+22
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs+22
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dfromf
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16386
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dmul
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dtof
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                CLC
                ADC     #14
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dfromf
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16352
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dadd
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dtof
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gs+24
                STA     _fcc_long_hi
                LDA     gs+22
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16404
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _arrfield_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_arrfield_L1
                LDA     #1
                CLC
                ADC     #gs+34
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #3
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                CLC
                ADC     #gs+34
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                INC
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     gs+35
                AND     #$00FF
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _arrfield_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #5
                STA     1,S   ; fccstk d=0 b=1
_arrfield_L2
                LDA     #0
                ASL
                CLC
                ADC     #gs+26
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                CLC
                ADC     #gs+26
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                LDA     #10000
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divu16
                STA     [_fcc_fpr0]
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     gs+26
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                ASL
                CLC
                ADC     #gs+30
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #3
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                CLC
                ADC     #gs+30
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                CLC
                ADC     #30
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                SEC
                SBC     #9
                STA     [_fcc_fpr0]
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     gs+30
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     ginit+2
                STA     _fcc_long_hi
                LDA     ginit+0
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16388
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _arrfield_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_arrfield_L3
                LDA     ginit+6
                STA     _fcc_long_hi
                LDA     ginit+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _arrfield_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_arrfield_L4
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     ginit+8
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 13
