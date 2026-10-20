                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_recurse.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fib
fib            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fib_FRAMESIZE
                DO      fib_STKGUARD
                BCC     fib_stkovf
                CMP     _fcc_stkfloor
                BCS     fib_stkok
fib_stkovf       JMP     _fcc_stkoflow
                FIN
fib_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+fib_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fib_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fib_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _p33_recurse_L1
                EOR     #$8000
_p33_recurse_L1
                BMI     *+5
                BRL     _p33_recurse_L0
                DO      6+fib_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fib_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fib_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #fib_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_recurse_L0
                DO      6+fib_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fib_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fib_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                PHA
                FGX2_FARCALL fib
                TAY
                PLA
                TYA
                STA     1,S   ; fccstk d=0 b=1
                DO      6+fib_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fib_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fib_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                PHA
                FGX2_FARCALL fib
                TAY
                PLA
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                TAY
                TSC
                CLC
                ADC     #fib_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fib_FRAMESIZE   EQU     4
fib_STKGUARD    EQU     1
                FGX2_EXPORT fact
fact            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fact_FRAMESIZE
                DO      fact_STKGUARD
                BCC     fact_stkovf
                CMP     _fcc_stkfloor
                BCS     fact_stkok
fact_stkovf       JMP     _fcc_stkoflow
                FIN
fact_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+fact_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fact_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fact_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _p33_recurse_L3
                EOR     #$8000
_p33_recurse_L3
                BPL     *+5
                BRL     _p33_recurse_L2
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #fact_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_recurse_L2
                DO      6+fact_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fact_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fact_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                PHA
                DO      8+fact_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fact_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fact_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                PHA
                FGX2_FARCALL fact
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAY
                TSC
                CLC
                ADC     #fact_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fact_FRAMESIZE   EQU     2
fact_STKGUARD    EQU     1
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
                LDA     #10
                PHA
                FGX2_FARCALL fib
                TAY
                PLA
                TYA
                TAX
                LDA     #55
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_recurse_L4
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
_p33_recurse_L4
                LDA     #5
                PHA
                FGX2_FARCALL fact
                TAY
                PLA
                TYA
                TAX
                LDA     #120
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_recurse_L5
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
_p33_recurse_L5
                LDA     #15
                PHA
                FGX2_FARCALL fib
                TAY
                PLA
                TYA
                TAX
                LDA     #610
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_recurse_L6
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
_p33_recurse_L6
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
