                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT triple_it
triple_it            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #triple_it_FRAMESIZE
                DO      triple_it_STKGUARD
                BCC     triple_it_stkovf
                CMP     _fcc_stkfloor
                BCS     triple_it_stkok
triple_it_stkovf       JMP     _fcc_stkoflow
                FIN
triple_it_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+triple_it_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+triple_it_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+triple_it_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #triple_it_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
triple_it_FRAMESIZE   EQU     0
triple_it_STKGUARD    EQU     0
                FGX2_EXPORT apply
apply            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #apply_FRAMESIZE
                DO      apply_STKGUARD
                BCC     apply_stkovf
                CMP     _fcc_stkfloor
                BCS     apply_stkok
apply_stkovf       JMP     _fcc_stkoflow
                FIN
apply_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+apply_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+apply_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+apply_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                DO      10+apply_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+apply_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+apply_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+apply_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+apply_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+apply_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PHK
                PEA     _fn_param_L0-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_fn_param_L0
                PLY
                TAY
                TSC
                CLC
                ADC     #apply_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
apply_FRAMESIZE   EQU     0
apply_STKGUARD    EQU     1
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
                LDA     #14
                PHA
                SEP     #$20
                MX      %10
                LDA     _fn_param_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fn_param_FA1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL apply
                PLY
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
                FGX2_RELOC_COUNT 5
