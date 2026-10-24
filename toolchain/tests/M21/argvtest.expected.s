                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from argvtest.c
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
                LDA     args_argc
                DO      6+main_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+main_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     #0
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                DO      10+main_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #12+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     10+main_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                LDA     #args_argv
                DO      8+main_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #10+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     8+main_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                DO      10+main_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+main_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+main_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+main_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _argvtest_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _argvtest_L1
                LDA     #1
                BRA     _argvtest_L2
_argvtest_L1
                LDA     #0
_argvtest_L2
                CMP     #0
                BEQ     _argvtest_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_argvtest_L0
                LDA     [_fcc_img0]
                AND     #$00FF
                TAX
                CMP     #47
                BNE     _argvtest_L3
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_argvtest_L3
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
