                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pp_adv3.c
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
                STA     1,S   ; fccstk d=0 b=1
                LDA     #4
                TAX
                CLC
                ADC     #3
                STA     3,S   ; fccstk d=0 b=3
                LDA     #2
                ASL
                TAX
                INC
                STA     5,S   ; fccstk d=0 b=5
                LDA     #1
                TAX
                CLC
                ADC     #3
                TAX
                CLC
                ADC     #3
                STA     7,S   ; fccstk d=0 b=7
                LDA     #0
                TAX
                CLC
                ADC     #3
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
                LDA     #1
                TAX
                INC
                INC
                TAX
                CLC
                ADC     #3
                STA     11,S   ; fccstk d=0 b=11
                LDA     #1
                STA     13,S   ; fccstk d=0 b=13
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                CLC
                ADC     5,S   ; fccstk d=0 b=5
                CLC
                ADC     7,S   ; fccstk d=0 b=7
                CLC
                ADC     9,S   ; fccstk d=0 b=9
                CLC
                ADC     11,S   ; fccstk d=0 b=11
                CLC
                ADC     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
