                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_param_knr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sum2
sum2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum2_FRAMESIZE
                DO      sum2_STKGUARD
                BCC     sum2_stkovf
                CMP     _fcc_stkfloor
                BCS     sum2_stkok
sum2_stkovf       JMP     _fcc_stkoflow
                FIN
sum2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sum2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+sum2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sum2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum2_FRAMESIZE   EQU     0
sum2_STKGUARD    EQU     0
                FGX2_EXPORT call2
call2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #call2_FRAMESIZE
                DO      call2_STKGUARD
                BCC     call2_stkovf
                CMP     _fcc_stkfloor
                BCS     call2_stkok
call2_stkovf       JMP     _fcc_stkoflow
                FIN
call2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+call2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+call2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+call2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+call2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+call2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+call2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      16+call2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+call2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+call2_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                PHA
                DO      16+call2_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+call2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+call2_FRAMESIZE,S   ; fccstk d=6 b=10 fs
                FIN
                PHA
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fn_param_knr_L0-1
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
_fn_param_knr_L0
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #call2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
call2_FRAMESIZE   EQU     0
call2_STKGUARD    EQU     1
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
                LDA     #2
                PHA
                LDA     #40
                PHA
                SEP     #$20
                MX      %10
                LDA     _fn_param_knr_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fn_param_knr_FA1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL call2
                TAY
                TSC
                CLC
                ADC     #8
                TCS
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
