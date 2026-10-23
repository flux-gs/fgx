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
                TXA
                CMP     #81
                BEQ     *+5
                BRL     _static_ptr_disp_L3
                LDA     #13
                TAX
                LDA:    arr,X
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _static_ptr_disp_L3
                LDA     #1
                BRL     _static_ptr_disp_L4
_static_ptr_disp_L3
                LDA     #0
_static_ptr_disp_L4
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L1
                LDA     #15
                TAX
                LDA:    arr,X
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _static_ptr_disp_L1
                LDA     #1
                BRL     _static_ptr_disp_L2
_static_ptr_disp_L1
                LDA     #0
_static_ptr_disp_L2
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L0
                LDA     _fcc_img0
                TAX
                TXA
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
                TXA
                CMP     #4660
                BEQ     *+5
                BRL     _static_ptr_disp_L10
                LDA     #1
                ASL
                TAX
                LDA:    iarr,X
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _static_ptr_disp_L10
                LDA     #1
                BRL     _static_ptr_disp_L11
_static_ptr_disp_L10
                LDA     #0
_static_ptr_disp_L11
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L8
                LDA     #3
                ASL
                TAX
                LDA:    iarr,X
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _static_ptr_disp_L8
                LDA     #1
                BRL     _static_ptr_disp_L9
_static_ptr_disp_L8
                LDA     #0
_static_ptr_disp_L9
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L6
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
                BEQ     *+5
                BRL     _static_ptr_disp_L12
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _static_ptr_disp_L12
                LDA     #1
                BRL     _static_ptr_disp_L13
_static_ptr_disp_L12
                LDA     #0
_static_ptr_disp_L13
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L6
                LDA     #1
                BRL     _static_ptr_disp_L7
_static_ptr_disp_L6
                LDA     #0
_static_ptr_disp_L7
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L5
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_static_ptr_disp_L5
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
                TXA
                CMP     #4369
                BEQ     *+5
                BRL     _static_ptr_disp_L17
                LDA     obj+2
                TAX
                TXA
                CMP     #8738
                BEQ     *+5
                BRL     _static_ptr_disp_L17
                LDA     #1
                BRL     _static_ptr_disp_L18
_static_ptr_disp_L17
                LDA     #0
_static_ptr_disp_L18
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L15
                SEP     #$20
                MX      %10
                LDA     op+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     op
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #obj
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _static_ptr_disp_L19
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _static_ptr_disp_L19
                LDA     #1
                BRL     _static_ptr_disp_L20
_static_ptr_disp_L19
                LDA     #0
_static_ptr_disp_L20
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L15
                LDA     #1
                BRL     _static_ptr_disp_L16
_static_ptr_disp_L15
                LDA     #0
_static_ptr_disp_L16
                CMP     #0
                BNE     *+5
                BRL     _static_ptr_disp_L14
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_static_ptr_disp_L14
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
