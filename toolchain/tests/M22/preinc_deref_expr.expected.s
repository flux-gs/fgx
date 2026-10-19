                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from preinc_deref_expr.c
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
                LDA     #buf
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                DEC
                STA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                LDA     #58
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _preinc_deref_expr_L1
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                LDA     #2
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _preinc_deref_expr_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _preinc_deref_expr_L3
                LDA     #0
                BRL     _preinc_deref_expr_L4
_preinc_deref_expr_L3
                LDA     #1
_preinc_deref_expr_L4
                CMP     #0
                BEQ     *+5
                BRL     _preinc_deref_expr_L1
                LDA     #0
                BRL     _preinc_deref_expr_L2
_preinc_deref_expr_L1
                LDA     #1
_preinc_deref_expr_L2
                CMP     #0
                BNE     *+5
                BRL     _preinc_deref_expr_L0
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
_preinc_deref_expr_L0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                DEC
                STA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                LDA     #56
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _preinc_deref_expr_L6
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                LDA     #1
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _preinc_deref_expr_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _preinc_deref_expr_L8
                LDA     #0
                BRL     _preinc_deref_expr_L9
_preinc_deref_expr_L8
                LDA     #1
_preinc_deref_expr_L9
                CMP     #0
                BEQ     *+5
                BRL     _preinc_deref_expr_L6
                LDA     #0
                BRL     _preinc_deref_expr_L7
_preinc_deref_expr_L6
                LDA     #1
_preinc_deref_expr_L7
                CMP     #0
                BNE     *+5
                BRL     _preinc_deref_expr_L5
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
_preinc_deref_expr_L5
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                LDA     #50
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _preinc_deref_expr_L11
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                LDA     #1
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _preinc_deref_expr_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _preinc_deref_expr_L13
                LDA     #0
                BRL     _preinc_deref_expr_L14
_preinc_deref_expr_L13
                LDA     #1
_preinc_deref_expr_L14
                CMP     #0
                BEQ     *+5
                BRL     _preinc_deref_expr_L11
                LDA     #0
                BRL     _preinc_deref_expr_L12
_preinc_deref_expr_L11
                LDA     #1
_preinc_deref_expr_L12
                CMP     #0
                BNE     *+5
                BRL     _preinc_deref_expr_L10
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
_preinc_deref_expr_L10
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
