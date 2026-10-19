                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from param_seed.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT p_sum
p_sum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #p_sum_FRAMESIZE
                DO      p_sum_STKGUARD
                BCC     p_sum_stkovf
                CMP     _fcc_stkfloor
                BCS     p_sum_stkok
p_sum_stkovf       JMP     _fcc_stkoflow
                FIN
p_sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+p_sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+p_sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+p_sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_param_seed_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _param_seed_L3
                EOR     #$8000
_param_seed_L3
                BMI     *+5
                BRL     _param_seed_L2
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img2
                STA     _fcc_img1
_param_seed_L1
                INC     _fcc_img0
                BRL     _param_seed_L0
_param_seed_L2
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img2
                TAY
                TSC
                CLC
                ADC     #p_sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
p_sum_FRAMESIZE   EQU     4
p_sum_STKGUARD    EQU     0
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
                LDA     #6
                PHA
                FGX2_FARCALL p_sum
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
                FGX2_RELOC_COUNT 4
