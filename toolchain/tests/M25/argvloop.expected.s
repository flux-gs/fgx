                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from argvloop.c
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
                STA     _fcc_fpr0+2
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
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
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
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
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
                STA     _fcc_fpr1+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _argvloop_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _argvloop_L1
                LDA     #0
                BRL     _argvloop_L2
_argvloop_L1
                LDA     #1
_argvloop_L2
                CMP     #0
                BNE     *+5
                BRL     _argvloop_L0
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
_argvloop_L0
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _argvloop_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _argvloop_L4
                LDA     #1
                BRL     _argvloop_L5
_argvloop_L4
                LDA     #0
_argvloop_L5
                CMP     #0
                BNE     *+5
                BRL     _argvloop_L3
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
_argvloop_L3
                LDA     [_fcc_img1]
                AND     #$00FF
                TAX
                LDA     #47
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _argvloop_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_argvloop_L6
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
                STA     _fcc_fpr0+2
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
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
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
                STA     _fcc_fpr1+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _argvloop_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _argvloop_L8
                LDA     #0
                BRL     _argvloop_L9
_argvloop_L8
                LDA     #1
_argvloop_L9
                CMP     #0
                BNE     *+5
                BRL     _argvloop_L7
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_argvloop_L7
                LDA     #0
                STA     _fcc_img0
_argvloop_L10
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                DO      6+main_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+main_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _argvloop_L13
                EOR     #$8000
_argvloop_L13
                BMI     *+5
                BRL     _argvloop_L12
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
                LDA     _fcc_img0
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _argvloop_L15
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _argvloop_L15
                LDA     #1
                BRL     _argvloop_L16
_argvloop_L15
                LDA     #0
_argvloop_L16
                CMP     #0
                BNE     *+5
                BRL     _argvloop_L14
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_argvloop_L14
_argvloop_L11
                INC     _fcc_img0
                BRL     _argvloop_L10
_argvloop_L12
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
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
