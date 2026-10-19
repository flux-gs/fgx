;---------------------------------------
; fcc 0.0 — generated from a.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                LDA     _fcc_ssp
                SEC
                SBC     #main_FRAMESIZE
                STA     _fcc_ssp
                FGX2_FARCALL f
                TAY
                LDA     _fcc_ssp
                CLC
                ADC     #main_FRAMESIZE
                STA     _fcc_ssp
                TYA
                RTL
main_FRAMESIZE   EQU     0
