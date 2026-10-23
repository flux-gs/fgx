                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dot_member_store_incdec.c
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
                STA     _fcc_img1
                LDA     #rows
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #row
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rows
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     B+0
                TAY
                LDA     _fcc_ptr+2
                STA     B+2
                TYA
                LDA     #0
                STA     _fcc_img0
_dot_member_store_incdec_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #4
                BVC     _dot_member_store_incdec_L3
                EOR     #$8000
_dot_member_store_incdec_L3
                BMI     *+5
                BRL     _dot_member_store_incdec_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #B
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
_dot_member_store_incdec_L1
                INC     _fcc_img0
                BRL     _dot_member_store_incdec_L0
_dot_member_store_incdec_L2
                LDA     #0
                TAX
                LDA:    row,X
                AND     #$00FF
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _dot_member_store_incdec_L5
                LDA     #3
                TAX
                LDA:    row,X
                AND     #$00FF
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dot_member_store_incdec_L5
                LDA     #1
                BRL     _dot_member_store_incdec_L6
_dot_member_store_incdec_L5
                LDA     #0
_dot_member_store_incdec_L6
                CMP     #0
                BNE     *+5
                BRL     _dot_member_store_incdec_L4
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #12
                STA     _fcc_img1
_dot_member_store_incdec_L4
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #B
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #5
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #B
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dot_member_store_incdec_L7
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img1
_dot_member_store_incdec_L7
                LDA     #9
                STA     B+10
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #B
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #B
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     B+10
                TAX
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _dot_member_store_incdec_L8
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img1
_dot_member_store_incdec_L8
                LDA     #65535
                STA     B+12
                TAY
                LDA     #0
                STA     B+14
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #B
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     B+14
                STA     _fcc_long_hi
                LDA     B+12
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
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
                BRL     _dot_member_store_incdec_L9
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img1
_dot_member_store_incdec_L9
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
