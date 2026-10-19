                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from krvararg.c
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
                LDA     #99
                PHA
                LDA     #42
                PHA
                FGX2_FARCALL knr
                TAY
                PLA
                PLA
                TYA
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
                FGX2_EXPORT knr
knr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #knr_FRAMESIZE
                DO      knr_STKGUARD
                BCC     knr_stkovf
                CMP     _fcc_stkfloor
                BCS     knr_stkok
knr_stkovf       JMP     _fcc_stkoflow
                FIN
knr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+knr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+knr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+knr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #42
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _krvararg_L1
                DO      8+knr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+knr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+knr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TAX
                LDA     #99
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _krvararg_L1
                LDA     #1
                BRL     _krvararg_L2
_krvararg_L1
                LDA     #0
_krvararg_L2
                CMP     #0
                BNE     *+5
                BRL     _krvararg_L0
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #knr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_krvararg_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #knr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
knr_FRAMESIZE   EQU     0
knr_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
