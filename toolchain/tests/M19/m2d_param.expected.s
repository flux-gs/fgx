                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m2d_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sum_2x3
sum_2x3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum_2x3_FRAMESIZE
                DO      sum_2x3_STKGUARD
                BCC     sum_2x3_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_2x3_stkok
sum_2x3_stkovf       JMP     _fcc_stkoflow
                FIN
sum_2x3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_2x3_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_2x3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                PHA
                DO      10+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      10+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      10+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      10+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      10+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+sum_2x3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_2x3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_2x3_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sum_2x3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_2x3_FRAMESIZE   EQU     0
sum_2x3_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum_2x3
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
