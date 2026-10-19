                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bfold_loc.c
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
                LDA     #8
                STA     1,S   ; fccstk d=0 b=1
                LDA     #5
                STA     3,S   ; fccstk d=0 b=3
                LDA     #3
                STA     5,S   ; fccstk d=0 b=5
                LDA     #12
                STA     7,S   ; fccstk d=0 b=7
                LDA     #10
                STA     9,S   ; fccstk d=0 b=9
                LDA     #6
                STA     11,S   ; fccstk d=0 b=11
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                SEC
                SBC     5,S   ; fccstk d=0 b=5
                AND     7,S   ; fccstk d=0 b=7
                ORA     9,S   ; fccstk d=0 b=9
                EOR     11,S   ; fccstk d=0 b=11
                STA     _fcc_img0
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
