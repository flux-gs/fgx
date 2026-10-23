                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_double.c
;---------------------------------------

                MX      %00
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
                DO      12+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+same_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+same_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
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
                FGX2_EXPORT _long_double_bits
_long_double_bits            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_long_double_bits_FRAMESIZE
                DO      _long_double_bits_STKGUARD
                BCC     _long_double_bits_stkovf
                CMP     _fcc_stkfloor
                BCS     _long_double_bits_stkok
_long_double_bits_stkovf       JMP     _fcc_stkoflow
                FIN
_long_double_bits_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_long_double_bits_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_long_double_bits_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_long_double_bits_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_long_double_bits_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_long_double_bits_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_long_double_bits_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      20+_long_double_bits_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_long_double_bits_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_long_double_bits_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_long_double_bits_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_long_double_bits_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_long_double_bits_FRAMESIZE,S   ; fccstk d=4 b=14 fs
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
                BNE     *+5
                BRL     _long_double_L0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+_long_double_bits_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_long_double_bits_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_long_double_bits_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_long_double_bits_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_long_double_bits_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_long_double_bits_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                BNE     *+5
                BRL     _long_double_L0
                LDA     #1
                BRL     _long_double_L1
_long_double_L0
                LDA     #0
_long_double_L1
                TAY
                TSC
                CLC
                ADC     #_long_double_bits_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_double_bits_FRAMESIZE   EQU     4
_long_double_bits_STKGUARD    EQU     0
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
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     13,S   ; fccstk d=0 b=13
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #$4008
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                LDA     _fcc_q2
                STA     g+4
                LDA     _fcc_q3
                STA     g+6
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4008
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _long_double_bits
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _long_double_L2
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                TXA
                CLC
                ADC     #10
                STA     13,S   ; fccstk d=0 b=13
_long_double_L2
                LDA     #8
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _long_double_L6
                LDA     #8
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _long_double_L6
                LDA     #1
                BRL     _long_double_L7
_long_double_L6
                LDA     #0
_long_double_L7
                CMP     #0
                BNE     *+5
                BRL     _long_double_L4
                LDA     #8
                SEC
                SBC     #8
                BVC     _long_double_L8
                EOR     #$8000
_long_double_L8
                BPL     *+5
                BRL     _long_double_L4
                LDA     #1
                BRL     _long_double_L5
_long_double_L4
                LDA     #0
_long_double_L5
                CMP     #0
                BNE     *+5
                BRL     _long_double_L3
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                TXA
                CLC
                ADC     #10
                STA     13,S   ; fccstk d=0 b=13
_long_double_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sv
                INC
                INC
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4008
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sv
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _long_double_bits
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _long_double_L10
                LDA     #10
                PHA
                LDA     #2
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _long_double_L10
                LDA     #1
                BRL     _long_double_L11
_long_double_L10
                LDA     #0
_long_double_L11
                CMP     #0
                BNE     *+5
                BRL     _long_double_L9
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                TXA
                CLC
                ADC     #11
                STA     13,S   ; fccstk d=0 b=13
_long_double_L9
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
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
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4008
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _long_double_bits
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _long_double_L12
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                TXA
                CLC
                ADC     #11
                STA     13,S   ; fccstk d=0 b=13
_long_double_L12
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
