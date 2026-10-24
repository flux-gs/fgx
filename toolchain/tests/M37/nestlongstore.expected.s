                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from nestlongstore.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_nestlongstore_o
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     _nestlongstore_p
                LDA     _fcc_fpr0+2
                STA     _nestlongstore_p+2
                LDA     #1
                STA     _nestlongstore_o+0
                LDA     #2
                STA     _nestlongstore_o+16
                LDA     #3
                STA     _nestlongstore_o+2
                LDA     #4
                STA     _nestlongstore_o+8
                LDA     #5
                STA     _nestlongstore_o+14
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
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
                LDA     #$E240
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L0
                LDA     _nestlongstore_o+2
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _nestlongstore_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L1
                LDA     _nestlongstore_o+8
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _nestlongstore_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L2
                LDA     _nestlongstore_o+0
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _nestlongstore_L4
                LDA     _nestlongstore_o+16
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _nestlongstore_L4
                LDA     #0
                BRL     _nestlongstore_L5
_nestlongstore_L4
                LDA     #1
_nestlongstore_L5
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L3
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                JSR     _fcc_long_neg
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L6
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L6
                LDA     _nestlongstore_o+8
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _nestlongstore_L7
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L7
                LDA     #9
                STA     _nestlongstore_gi
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _nestlongstore_gi
                JSR     _fcc_long_from_int
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0009
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L8
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L8
                LDA     _nestlongstore_o+8
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _nestlongstore_L9
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L9
                LDA     #$FFFD
                STA     _nestlongstore_gi
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _nestlongstore_gi
                JSR     _fcc_long_from_int
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L10
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L10
                LDA     #$000F
                STA     _fcc_long_hi
                LDA     #$423F
                STA     _nestlongstore_gl
                TAY
                LDA     _fcc_long_hi
                STA     _nestlongstore_gl+2
                TYA
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _nestlongstore_gl+2
                STA     _fcc_long_hi
                LDA     _nestlongstore_gl
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _nestlongstore_o+6
                STA     _fcc_long_hi
                LDA     _nestlongstore_o+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$000F
                STA     _fcc_long_hi
                LDA     #$423F
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L11
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L11
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     #16388
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
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L12
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L12
                LDA     _nestlongstore_o+8
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _nestlongstore_L13
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L13
                LDA     _nestlongstore_o+14
                TAX
                TXA
                CMP     #5
                BNE     *+5
                BRL     _nestlongstore_L14
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L14
                LDA     #6
                STA     _nestlongstore_gi
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     _nestlongstore_gi
                JSR     _fcc_itof
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
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
                LDA     #16408
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
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L15
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L15
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                INC
                INC
                STA     _fcc_fpr0
                LDA     #41
                STA     [_fcc_fpr0]
                LDA     _nestlongstore_o+2
                TAX
                TXA
                CMP     #41
                BNE     *+5
                BRL     _nestlongstore_L16
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L16
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$004D
                STA     _nestlongstore_o+4
                TAY
                LDA     _fcc_long_hi
                STA     _nestlongstore_o+6
                TYA
                SEP     #$20
                MX      %10
                LDA     _nestlongstore_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _nestlongstore_p
                CLC
                ADC     #4
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$004D
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _nestlongstore_L17
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L17
                LDA     _nestlongstore_o+2
                TAX
                TXA
                CMP     #41
                BNE     *+5
                BRL     _nestlongstore_L18
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_nestlongstore_L18
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
