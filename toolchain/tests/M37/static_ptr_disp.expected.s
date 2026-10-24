                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_ptr_disp.c
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
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     cp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     cp
                STA     _fcc_fpr0
                LDA     #81
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #14
                TAX
                LDA:    arr,X
                AND     #$00FF
                TAX
                CMP     #81
                BNE     _static_ptr_disp_L0
                LDA     #13
                TAX
                LDA:    arr,X
                AND     #$00FF
                BNE     _static_ptr_disp_L0
                LDA     #15
                TAX
                LDA:    arr,X
                AND     #$00FF
                BNE     _static_ptr_disp_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_static_ptr_disp_L0
                SEP     #$20
                MX      %10
                LDA     ip+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ip
                STA     _fcc_fpr0
                LDA     #4660
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                TAX
                LDA:    iarr,X
                TAX
                CMP     #4660
                BNE     _static_ptr_disp_L1
                LDA     #1
                ASL
                TAX
                LDA:    iarr,X
                CMP     #0
                BNE     _static_ptr_disp_L1
                LDA     #3
                ASL
                TAX
                LDA:    iarr,X
                CMP     #0
                BNE     _static_ptr_disp_L1
                SEP     #$20
                MX      %10
                LDA     ip+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ip
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     ap+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     ap
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _static_ptr_disp_L2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _static_ptr_disp_L2
                LDA     #1
                BRA     _static_ptr_disp_L3
_static_ptr_disp_L2
                LDA     #0
_static_ptr_disp_L3
                CMP     #0
                BEQ     _static_ptr_disp_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_static_ptr_disp_L1
                LDA     #4369
                STA     obj+0
                SEP     #$20
                MX      %10
                LDA     mp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     mp
                STA     _fcc_fpr0
                LDA     #8738
                STA     [_fcc_fpr0]
                LDA     obj+0
                TAX
                CMP     #4369
                BNE     _static_ptr_disp_L4
                LDA     obj+2
                TAX
                CMP     #8738
                BNE     _static_ptr_disp_L4
                SEP     #$20
                MX      %10
                LDA     op+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     op
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #obj
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _static_ptr_disp_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _static_ptr_disp_L5
                LDA     #1
                BRA     _static_ptr_disp_L6
_static_ptr_disp_L5
                LDA     #0
_static_ptr_disp_L6
                CMP     #0
                BEQ     _static_ptr_disp_L4
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_static_ptr_disp_L4
                LDA     _fcc_img0
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
