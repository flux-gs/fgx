;---------------------------------------
; fcc 0.0 — generated from b.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f
f            ENT
                LDA     _fcc_ssp
                SEC
                SBC     #f_FRAMESIZE
                STA     _fcc_ssp
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_b_S0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     [_fcc_img0]
                AND     #$00FF
                TAY
                LDA     _fcc_ssp
                CLC
                ADC     #f_FRAMESIZE
                STA     _fcc_ssp
                TYA
                RTL
f_FRAMESIZE   EQU     4
