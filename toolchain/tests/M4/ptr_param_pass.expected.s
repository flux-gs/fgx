                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_param_pass.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT dbl
dbl            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dbl_FRAMESIZE
                DO      dbl_STKGUARD
                BCC     dbl_stkovf
                CMP     _fcc_stkfloor
                BCS     dbl_stkok
dbl_stkovf       JMP     _fcc_stkoflow
                FIN
dbl_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+dbl_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dbl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dbl_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+dbl_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dbl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dbl_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                DO      8+dbl_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dbl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dbl_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      10+dbl_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+dbl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+dbl_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #dbl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dbl_FRAMESIZE   EQU     0
dbl_STKGUARD    EQU     0
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
                LDA     #21
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL dbl
                TAY
                TSC
                CLC
                ADC     #4
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
