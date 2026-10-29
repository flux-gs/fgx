                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrpost.c
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
                LDA     #1
                STA     _fcc_img1
                LDA     #10
                STA     _fcc_img0
                LDA     #w
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #4
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     _fcc_img1
                ASL
                CLC
                ADC     #w
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     #b
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #9
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #2
                CLC
                ADC     #b
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
                STA     _fcc_tmp_b
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                TAX
                LDA:    w,X
                CMP     #5
                BNE     _arrpost_L0
                LDA     _fcc_img0
                CLC
                ADC     #16
                STA     _fcc_img0
_arrpost_L0
                LDA     #2
                TAX
                LDA:    b,X
                AND     #$00FF
                CMP     #8
                BNE     _arrpost_L1
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_arrpost_L1
                LDA     _fcc_img1
                TAX
                CMP     #1
                BNE     _arrpost_L2
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #8
                STA     _fcc_img0
_arrpost_L2
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
