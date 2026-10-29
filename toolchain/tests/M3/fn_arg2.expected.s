                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_arg2.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT mul
mul            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mul_FRAMESIZE
                DO      mul_STKGUARD
                BCC     mul_stkovf
                CMP     _fcc_stkfloor
                BCS     mul_stkok
mul_stkovf       JMP     _fcc_stkoflow
                FIN
mul_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+mul_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+mul_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+mul_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+mul_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+mul_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+mul_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                TAY
                TSC
                CLC
                ADC     #mul_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mul_FRAMESIZE   EQU     0
mul_STKGUARD    EQU     0
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
                LDA     #7
                PHA
                LDA     #6
                PHA
                FGX2_FARCALL mul
                PLY
                PLY
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
