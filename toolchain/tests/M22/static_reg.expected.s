                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_reg.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT accum
accum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #accum_FRAMESIZE
                DO      accum_STKGUARD
                BCC     accum_stkovf
                CMP     _fcc_stkfloor
                BCS     accum_stkok
accum_stkovf       JMP     _fcc_stkoflow
                FIN
accum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                STA     1,S   ; fccstk d=0 b=1
                LDA     accum_sl_calls
                CLC
                ADC     #1
                STA     accum_sl_calls
                TAX
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                TAY
                TSC
                CLC
                ADC     #accum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
accum_FRAMESIZE   EQU     2
accum_STKGUARD    EQU     0
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
                FGX2_FARCALL accum
                STA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL accum
                STA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL accum
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #21
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
                FGX2_RELOC_COUNT 6
