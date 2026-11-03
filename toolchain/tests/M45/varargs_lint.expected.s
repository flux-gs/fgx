                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from varargs_lint.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sum
sum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum_FRAMESIZE
                DO      sum_STKGUARD
                BCC     sum_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_stkok
sum_stkovf       JMP     _fcc_stkoflow
                FIN
sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #8+sum_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
_varargs_lint_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img1
                LDA     _fcc_tmp_b
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _varargs_lint_L2
                EOR     #$8000
_varargs_lint_L2
                BPL     _varargs_lint_L1
                LDA     _fcc_img0
                PHA
                LDA     [_fcc_img2]
                PHA
                LDA     _fcc_img2
                INC
                INC
                STA     _fcc_img2
                PLA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                BRA     _varargs_lint_L0
_varargs_lint_L1
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_FRAMESIZE   EQU     6
sum_STKGUARD    EQU     0
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
                LDA     #15
                PHA
                LDA     #20
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL sum
                PLY
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
                FGX2_RELOC_COUNT 4
