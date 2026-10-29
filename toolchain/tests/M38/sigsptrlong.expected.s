                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sigsptrlong.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL same
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_EXPORT same
same            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #same_FRAMESIZE
                DO      same_STKGUARD
                BCC     same_stkovf
                CMP     _fcc_stkfloor
                BCS     same_stkok
same_stkovf       JMP     _fcc_stkoflow
                FIN
same_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+same_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+same_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _sigsptrlong_L0
                LDA     #42
                BRA     _sigsptrlong_L1
_sigsptrlong_L0
                LDA     #7
_sigsptrlong_L1
                TAY
                TSC
                CLC
                ADC     #same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
same_FRAMESIZE   EQU     0
same_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
