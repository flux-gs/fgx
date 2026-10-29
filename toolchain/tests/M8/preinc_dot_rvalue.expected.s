                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from preinc_dot_rvalue.c
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
                LDA     #10
                STA     c+8
                LDA     #20
                STA     c+10
                LDA     #5
                STA     c+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #7
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                CLC
                ADC     #8
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
                INC
                STA     [_fcc_ptr]
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                CLC
                ADC     #10
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
                DEC
                STA     [_fcc_ptr]
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
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
                INC
                STA     [_fcc_ptr]
                STA     _fcc_img2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
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
                INC
                STA     [_fcc_ptr]
                STA     _fcc_img3
                LDA     _fcc_img0
                PHA
                LDA     c+8
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _preinc_dot_rvalue_L5
                LDA     _fcc_img1
                PHA
                LDA     c+10
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _preinc_dot_rvalue_L5
                LDA     #0
                BRL     _preinc_dot_rvalue_L6
_preinc_dot_rvalue_L5
                LDA     #1
_preinc_dot_rvalue_L6
                CMP     #0
                BEQ     *+5
                BRL     _preinc_dot_rvalue_L3
                LDA     _fcc_img2
                PHA
                LDA     c+0
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _preinc_dot_rvalue_L3
                LDA     #0
                BRL     _preinc_dot_rvalue_L4
_preinc_dot_rvalue_L3
                LDA     #1
_preinc_dot_rvalue_L4
                CMP     #0
                BEQ     *+5
                BRL     _preinc_dot_rvalue_L1
                LDA     _fcc_img3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _preinc_dot_rvalue_L1
                LDA     #0
                BRL     _preinc_dot_rvalue_L2
_preinc_dot_rvalue_L1
                LDA     #1
_preinc_dot_rvalue_L2
                CMP     #0
                BNE     *+5
                BRL     _preinc_dot_rvalue_L0
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
_preinc_dot_rvalue_L0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_img1
                CLC
                ADC     _fcc_img2
                CLC
                ADC     _fcc_img3
                TAX
                TXA
                DEC
                DEC
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
