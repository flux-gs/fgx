                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from f_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT addf
addf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #addf_FRAMESIZE
                DO      addf_STKGUARD
                BCC     addf_stkovf
                CMP     _fcc_stkfloor
                BCS     addf_stkok
addf_stkovf       JMP     _fcc_stkoflow
                FIN
addf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+addf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+addf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+addf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+addf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+addf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+addf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+addf_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+addf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+addf_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+addf_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+addf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+addf_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fadd
                TAY
                TSC
                CLC
                ADC     #addf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
addf_FRAMESIZE   EQU     0
addf_STKGUARD    EQU     0
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
                DO      14+scale_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+scale_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+scale_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                FGX2_EXPORT negf
negf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #negf_FRAMESIZE
                DO      negf_STKGUARD
                BCC     negf_stkovf
                CMP     _fcc_stkfloor
                BCS     negf_stkok
negf_stkovf       JMP     _fcc_stkoflow
                FIN
negf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+negf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+negf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+negf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+negf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+negf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+negf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                JSR     _fcc_fneg
                TAY
                TSC
                CLC
                ADC     #negf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
negf_FRAMESIZE   EQU     0
negf_STKGUARD    EQU     0
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
                LDA     #16384
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16376
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL addf
                PLY
                PLY
                PLY
                PLY
                JSR     _fcc_ftoi
                TAX
                CMP     #3
                BEQ     _f_param_L0
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
_f_param_L0
                LDA     #16384
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16452
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL addf
                PLY
                PLY
                PLY
                PLY
                JSR     _fcc_ftoi
                TAX
                CMP     #42
                BEQ     _f_param_L1
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
_f_param_L1
                LDA     #14
                PHA
                LDA     #16392
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                FGX2_FARCALL _fcc_dtof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL scale
                PLY
                PLY
                PLY
                JSR     _fcc_ftoi
                TAX
                CMP     #42
                BEQ     _f_param_L2
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
_f_param_L2
                LDA     #16453
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dtof
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL negf
                PLY
                PLY
                JSR     _fcc_ftoi
                TAX
                CMP     #42
                BEQ     _f_param_L3
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
_f_param_L3
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
                FGX2_RELOC_COUNT 15
