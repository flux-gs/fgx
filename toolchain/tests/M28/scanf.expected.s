                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from scanf.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _scanf_mag
_scanf_mag            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_scanf_mag_FRAMESIZE
                DO      _scanf_mag_STKGUARD
                BCC     _scanf_mag_stkovf
                CMP     _fcc_stkfloor
                BCS     _scanf_mag_stkok
_scanf_mag_stkovf       JMP     _fcc_stkoflow
                FIN
_scanf_mag_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #0
                JSR     _fcc_long_from_int
                FGX2_FARCALL _fcc_dfroml
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
                FGX2_FARCALL _fcc_dcmp
                BMI     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     *+5
                BRL     _scanf_L0
                DO      12+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                BRL     _scanf_L1
_scanf_L0
                DO      12+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_scanf_mag_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_scanf_mag_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_scanf_mag_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
_scanf_L1
                TAY
                TSC
                CLC
                ADC     #_scanf_mag_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_mag_FRAMESIZE   EQU     0
_scanf_mag_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #24
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _scanf_L9
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #12
                BEQ     *+5
                BRL     _scanf_L9
                LDA     #0
                BRL     _scanf_L10
_scanf_L9
                LDA     #1
_scanf_L10
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L7
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #$FFDE
                BEQ     *+5
                BRL     _scanf_L7
                LDA     #0
                BRL     _scanf_L8
_scanf_L7
                LDA     #1
_scanf_L8
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L5
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #63
                BEQ     *+5
                BRL     _scanf_L5
                LDA     #0
                BRL     _scanf_L6
_scanf_L5
                LDA     #1
_scanf_L6
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L3
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CMP     #255
                BEQ     *+5
                BRL     _scanf_L3
                LDA     #0
                BRL     _scanf_L4
_scanf_L3
                LDA     #1
_scanf_L4
                CMP     #0
                BNE     *+5
                BRL     _scanf_L2
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
_scanf_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _scanf_L14
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L14
                LDA     #0
                BRL     _scanf_L15
_scanf_L14
                LDA     #1
_scanf_L15
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L12
                LDA     15,S   ; fccstk d=0 b=15
                CMP     #$FFFB
                BEQ     *+5
                BRL     _scanf_L12
                LDA     #0
                BRL     _scanf_L13
_scanf_L12
                LDA     #1
_scanf_L13
                CMP     #0
                BNE     *+5
                BRL     _scanf_L11
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
_scanf_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _scanf_L19
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #123
                BEQ     *+5
                BRL     _scanf_L19
                LDA     #0
                BRL     _scanf_L20
_scanf_L19
                LDA     #1
_scanf_L20
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L17
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #45
                BEQ     *+5
                BRL     _scanf_L17
                LDA     #0
                BRL     _scanf_L18
_scanf_L17
                LDA     #1
_scanf_L18
                CMP     #0
                BNE     *+5
                BRL     _scanf_L16
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
_scanf_L16
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L22
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _scanf_L22
                LDA     #0
                BRL     _scanf_L23
_scanf_L22
                LDA     #1
_scanf_L23
                CMP     #0
                BNE     *+5
                BRL     _scanf_L21
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
_scanf_L21
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #42
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S9
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _scanf_L31
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #42
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #104
                BEQ     *+5
                BRL     _scanf_L31
                LDA     #0
                BRL     _scanf_L32
_scanf_L31
                LDA     #1
_scanf_L32
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L29
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #42
                PHA
                LDA     #4
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #111
                BEQ     *+5
                BRL     _scanf_L29
                LDA     #0
                BRL     _scanf_L30
_scanf_L29
                LDA     #1
_scanf_L30
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L27
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #42
                PHA
                LDA     #5
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L27
                LDA     #0
                BRL     _scanf_L28
_scanf_L27
                LDA     #1
_scanf_L28
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L25
                LDA     17,S   ; fccstk d=0 b=17
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BEQ     *+5
                BRL     _scanf_L25
                LDA     #0
                BRL     _scanf_L26
_scanf_L25
                LDA     #1
_scanf_L26
                CMP     #0
                BNE     *+5
                BRL     _scanf_L24
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
_scanf_L24
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #58
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S11
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S10
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _scanf_L38
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #58
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _scanf_L38
                LDA     #0
                BRL     _scanf_L39
_scanf_L38
                LDA     #1
_scanf_L39
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L36
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #58
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L36
                LDA     #0
                BRL     _scanf_L37
_scanf_L36
                LDA     #1
_scanf_L37
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L34
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #123
                BEQ     *+5
                BRL     _scanf_L34
                LDA     #0
                BRL     _scanf_L35
_scanf_L34
                LDA     #1
_scanf_L35
                CMP     #0
                BNE     *+5
                BRL     _scanf_L33
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L33
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S13
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S12
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _scanf_L43
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L43
                LDA     #0
                BRL     _scanf_L44
_scanf_L43
                LDA     #1
_scanf_L44
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L41
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _scanf_L41
                LDA     #0
                BRL     _scanf_L42
_scanf_L41
                LDA     #1
_scanf_L42
                CMP     #0
                BNE     *+5
                BRL     _scanf_L40
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L40
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S15
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L46
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4020
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fne
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L46
                LDA     #0
                BRL     _scanf_L47
_scanf_L46
                LDA     #1
_scanf_L47
                CMP     #0
                BNE     *+5
                BRL     _scanf_L45
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L45
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S17
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L49
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$447A
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fne
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L49
                LDA     #0
                BRL     _scanf_L50
_scanf_L49
                LDA     #1
_scanf_L50
                CMP     #0
                BNE     *+5
                BRL     _scanf_L48
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L48
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S19
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L52
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$3EC0
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_fneg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_fne
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L52
                LDA     #0
                BRL     _scanf_L53
_scanf_L52
                LDA     #1
_scanf_L53
                CMP     #0
                BNE     *+5
                BRL     _scanf_L51
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L51
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S21
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L55
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_q3
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_q2
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=0 b=23
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16313
                STA     _fcc_q3
                LDA     #39321
                STA     _fcc_q2
                LDA     #39321
                STA     _fcc_long_hi
                LDA     #39322
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
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L55
                LDA     #0
                BRL     _scanf_L56
_scanf_L55
                LDA     #1
_scanf_L56
                CMP     #0
                BNE     *+5
                BRL     _scanf_L54
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L54
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S23
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S22
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L58
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_q3
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_q2
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=0 b=23
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16877
                STA     _fcc_q3
                LDA     #37932
                STA     _fcc_q2
                LDA     #36870
                STA     _fcc_long_hi
                LDA     #28312
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
                FGX2_FARCALL _fcc_dsub
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _scanf_mag
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16048
                STA     _fcc_q3
                LDA     #50935
                STA     _fcc_q2
                LDA     #41141
                STA     _fcc_long_hi
                LDA     #60813
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
                FGX2_FARCALL _fcc_dcmp
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L58
                LDA     #0
                BRL     _scanf_L59
_scanf_L58
                LDA     #1
_scanf_L59
                CMP     #0
                BNE     *+5
                BRL     _scanf_L57
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L57
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S25
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S24
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L61
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_q3
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_q2
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=0 b=23
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16228
                STA     _fcc_q3
                LDA     #31457
                STA     _fcc_q2
                LDA     #18350
                STA     _fcc_long_hi
                LDA     #5243
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
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _scanf_mag
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #15410
                STA     _fcc_q3
                LDA     #29277
                STA     _fcc_q2
                LDA     #53714
                STA     _fcc_long_hi
                LDA     #17324
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
                FGX2_FARCALL _fcc_dcmp
                CMP     #1
                BEQ     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L61
                LDA     #0
                BRL     _scanf_L62
_scanf_L61
                LDA     #1
_scanf_L62
                CMP     #0
                BNE     *+5
                BRL     _scanf_L60
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L60
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #30
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S26
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _scanf_L64
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_q3
                LDA     35,S   ; fccstk d=0 b=35
                STA     _fcc_q2
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_long_hi
                LDA     31,S   ; fccstk d=0 b=31
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16344
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
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L64
                LDA     #0
                BRL     _scanf_L65
_scanf_L64
                LDA     #1
_scanf_L65
                CMP     #0
                BNE     *+5
                BRL     _scanf_L63
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L63
                LDA     #99
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S28
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S27
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #$FFFF
                BEQ     *+5
                BRL     _scanf_L67
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _scanf_L67
                LDA     #0
                BRL     _scanf_L68
_scanf_L67
                LDA     #1
_scanf_L68
                CMP     #0
                BNE     *+5
                BRL     _scanf_L66
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L66
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S28
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S29
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L70
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _scanf_L70
                LDA     #0
                BRL     _scanf_L71
_scanf_L70
                LDA     #1
_scanf_L71
                CMP     #0
                BNE     *+5
                BRL     _scanf_L69
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L69
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S31
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S30
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fopen
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     41,S   ; fccstk d=0 b=41
                LDA     _fcc_fpr0
                STA     39,S   ; fccstk d=0 b=39
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _scanf_L73
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _scanf_L73
                LDA     #1
                BRL     _scanf_L74
_scanf_L73
                LDA     #0
_scanf_L74
                CMP     #0
                BNE     *+5
                BRL     _scanf_L72
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L72
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S32
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fputs
                TSC
                CLC
                ADC     #8
                TCS
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S33
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S30
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fopen
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     41,S   ; fccstk d=0 b=41
                LDA     _fcc_fpr0
                STA     39,S   ; fccstk d=0 b=39
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _scanf_L76
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _scanf_L76
                LDA     #1
                BRL     _scanf_L77
_scanf_L76
                LDA     #0
_scanf_L77
                CMP     #0
                BNE     *+5
                BRL     _scanf_L75
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L75
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S34
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     53,S   ; fccstk d=12 b=41
                STA     _fcc_fpr0+2
                LDA     51,S   ; fccstk d=12 b=39
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fscanf
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _scanf_L81
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #42
                BEQ     *+5
                BRL     _scanf_L81
                LDA     #0
                BRL     _scanf_L82
_scanf_L81
                LDA     #1
_scanf_L82
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L79
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_q3
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_q2
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=0 b=23
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16394
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
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
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _scanf_L79
                LDA     #0
                BRL     _scanf_L80
_scanf_L79
                LDA     #1
_scanf_L80
                CMP     #0
                BNE     *+5
                BRL     _scanf_L78
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L78
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                DEC
                STA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #0
_scanf_L86
                BPL     *+5
                BRL     _scanf_L84
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                CLC
                ADC     #1
                STA     [_fcc_fpr0]
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BRL     _scanf_L85
_scanf_L84
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _filbuf
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
_scanf_L85
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _scanf_L83
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L83
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S28
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     49,S   ; fccstk d=8 b=41
                STA     _fcc_fpr0+2
                LDA     47,S   ; fccstk d=8 b=39
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fscanf
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #$FFFF
                BNE     *+5
                BRL     _scanf_L87
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_scanf_L87
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0+2
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_scanf_S30
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
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
main_FRAMESIZE   EQU     74
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 39
