                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from f_knr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT scale
scale            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #scale_FRAMESIZE
                DO      scale_STKGUARD
                BCC     scale_stkovf
                CMP     _fcc_stkfloor
                BCS     scale_stkok
scale_stkovf       JMP     _fcc_stkoflow
                FIN
scale_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+scale_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+scale_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+scale_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+scale_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                FGX2_FARCALL _fcc_dtof
                DO      6+scale_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+scale_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                DO      8+scale_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #10+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     8+scale_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TYA
                DO      8+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+scale_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+scale_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      18+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+scale_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
                JSR     _fcc_itof
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fmul
                JSR     _fcc_ftoi
                TAY
                TSC
                CLC
                ADC     #scale_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
scale_FRAMESIZE   EQU     0
scale_STKGUARD    EQU     0
                FGX2_EXPORT dpar
dpar            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dpar_FRAMESIZE
                DO      dpar_STKGUARD
                BCC     dpar_stkovf
                CMP     _fcc_stkfloor
                BCS     dpar_stkok
dpar_stkovf       JMP     _fcc_stkoflow
                FIN
dpar_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+dpar_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+dpar_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+dpar_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dpar_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      20+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+dpar_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_q3
                DO      18+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+dpar_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_q2
                DO      16+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+dpar_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+dpar_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+dpar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+dpar_FRAMESIZE,S   ; fccstk d=8 b=6 fs
                FIN
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dadd
                FGX2_FARCALL _fcc_dtol
                TAY
                TSC
                CLC
                ADC     #dpar_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dpar_FRAMESIZE   EQU     0
dpar_STKGUARD    EQU     0
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
                LDA     #4
                PHA
                LDA     #16388
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL scale
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                TXA
                CMP     #10
                BEQ     _f_knr_L0
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
_f_knr_L0
                LDA     #84
                PHA
                LDA     #16352
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL scale
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                TXA
                CMP     #42
                BEQ     _f_knr_L1
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
_f_knr_L1
                LDA     #16392
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL dpar
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                TXA
                CMP     #6
                BEQ     _f_knr_L2
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
_f_knr_L2
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
