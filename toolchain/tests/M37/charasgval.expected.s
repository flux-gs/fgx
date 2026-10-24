                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from charasgval.c
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
                LDA     #449
                STA     _fcc_img1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ga
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
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
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     #0
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_img3
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L0
                INC     _fcc_img0
_charasgval_L0
                LDA     _fcc_img1
                SEP     #$20
                MX      %10
                STA     g
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L1
                INC     _fcc_img0
_charasgval_L1
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDA     _fcc_img1
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L2
                INC     _fcc_img0
_charasgval_L2
                LDA     #2
                CLC
                ADC     #ga
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img1
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L3
                INC     _fcc_img0
_charasgval_L3
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     _fcc_img1
                SEP     #$20
                MX      %10
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L4
                INC     _fcc_img0
_charasgval_L4
                LDA     _fcc_img1
                SEP     #$20
                MX      %10
                STA     gs+2
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L5
                INC     _fcc_img0
_charasgval_L5
                LDA     #128
                AND     #$00FF
                TAX
                CLC
                ADC     #321
                STA     _fcc_img3
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L6
                INC     _fcc_img0
_charasgval_L6
                LDA     #705
                SEP     #$20
                MX      %10
                STA     g
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     _fcc_img1
                TAX
                CMP     #193
                BNE     _charasgval_L7
                INC     _fcc_img0
_charasgval_L7
                LDA     _fcc_img0
                TAX
                CMP     #8
                BNE     _charasgval_L8
                LDA     _fcc_img2
                TAX
                CLC
                ADC     #40
                STA     _fcc_img2
_charasgval_L8
                LDA     _fcc_img1
                SEP     #$20
                MX      %10
                STA     g
                REP     #$20
                MX      %00
                LDA     g
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L9
                LDA     #0
                TAX
                LDA:    ga,X
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L9
                LDA     #2
                TAX
                LDA:    ga,X
                AND     #$00FF
                TAX
                CMP     #193
                BNE     _charasgval_L9
                LDA     _fcc_img2
                TAX
                CLC
                ADC     #2
                STA     _fcc_img2
_charasgval_L9
                LDA     _fcc_img2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
