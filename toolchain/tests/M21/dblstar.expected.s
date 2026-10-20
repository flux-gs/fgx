                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dblstar.c
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
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
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
                FGX2_RELOC_COUNT 2
