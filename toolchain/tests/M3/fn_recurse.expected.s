                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_recurse.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fact
fact            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fact_FRAMESIZE
                DO      fact_STKGUARD
                BCC     fact_stkovf
                CMP     _fcc_stkfloor
                BCS     fact_stkok
fact_stkovf       JMP     _fcc_stkoflow
                FIN
fact_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+fact_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fact_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fact_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _fn_recurse_L1
                EOR     #$8000
_fn_recurse_L1
                BMI     _fn_recurse_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #fact_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fn_recurse_L0
                DO      6+fact_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fact_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fact_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      8+fact_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fact_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fact_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                TAX
                TXA
                SEC
                SBC     #1
                PHA
                FGX2_FARCALL fact
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAY
                TSC
                CLC
                ADC     #fact_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fact_FRAMESIZE   EQU     0
fact_STKGUARD    EQU     1
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
                LDA     #5
                PHA
                FGX2_FARCALL fact
                TAY
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
                FGX2_RELOC_COUNT 5
