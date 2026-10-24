                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_ecopy.c
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_struct_ecopy_S0
                STA     _fcc_fpr0
                STA     gs
                LDA     _fcc_fpr0+2
                STA     gs+2
                LDA     #0
                STA     _fcc_img0
_struct_ecopy_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #4
                BVC     _struct_ecopy_L3
                EOR     #$8000
_struct_ecopy_L3
                BMI     *+5
                BRL     _struct_ecopy_L2
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     gs+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     gs
                STA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #100
                JSR     _fcc_long_from_int
                LDY     #6
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #8
                STA     [_fcc_fpr0],Y
                TXA
_struct_ecopy_L1
                INC     _fcc_img0
                BRL     _struct_ecopy_L0
_struct_ecopy_L2
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #777
                JSR     _fcc_long_from_int
                LDY     #6
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #8
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #3
                STA     _fcc_img0
_struct_ecopy_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _struct_ecopy_L7
                EOR     #$8000
_struct_ecopy_L7
                BMI     *+5
                BRL     _struct_ecopy_L6
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                TAX
                TXA
                DEC
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                LDY     #8
_struct_ecopy_L8
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_ecopy_L8
_struct_ecopy_L5
                DEC     _fcc_img0
                BRL     _struct_ecopy_L4
_struct_ecopy_L6
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #arr
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
                TXA
                CMP     #0
                BNE     *+5
                BRL     _struct_ecopy_L9
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
_struct_ecopy_L9
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
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
                TXA
                CMP     #0
                BNE     *+5
                BRL     _struct_ecopy_L10
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
_struct_ecopy_L10
                LDA     #2
                ASL
                ASL
                INC
                INC
                ASL
                CLC
                ADC     #arr
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
                TXA
                CMP     #10
                BNE     *+5
                BRL     _struct_ecopy_L11
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
_struct_ecopy_L11
                LDA     #3
                ASL
                ASL
                CLC
                ADC     #3
                ASL
                CLC
                ADC     #arr
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
                TXA
                CMP     #20
                BNE     *+5
                BRL     _struct_ecopy_L12
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
_struct_ecopy_L12
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #777
                JSR     _fcc_long_from_int
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
                BRL     _struct_ecopy_L13
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
_struct_ecopy_L13
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
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
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #104
                BNE     *+5
                BRL     _struct_ecopy_L14
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
_struct_ecopy_L14
                LDA     #3
                ASL
                ASL
                CLC
                ADC     #3
                ASL
                CLC
                ADC     #arr
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
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #105
                BNE     *+5
                BRL     _struct_ecopy_L15
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
_struct_ecopy_L15
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
