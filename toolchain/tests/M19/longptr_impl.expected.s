                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longptr_impl.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT ret
ret            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ret_FRAMESIZE
                DO      ret_STKGUARD
                BCC     ret_stkovf
                CMP     _fcc_stkfloor
                BCS     ret_stkok
ret_stkovf       JMP     _fcc_stkoflow
                FIN
ret_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+ret_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ret_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ret_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+ret_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ret_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ret_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     _fcc_long_hi
                SEP     #$20
                MX      %10
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #ret_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ret_FRAMESIZE   EQU     0
ret_STKGUARD    EQU     0
                FGX2_EXPORT arg
arg            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #arg_FRAMESIZE
                DO      arg_STKGUARD
                BCC     arg_stkovf
                CMP     _fcc_stkfloor
                BCS     arg_stkok
arg_stkovf       JMP     _fcc_stkoflow
                FIN
arg_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+arg_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+arg_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+arg_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr1+2
                DO      10+arg_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+arg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+arg_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L0
                LDA     #1
                BRL     _longptr_impl_L1
_longptr_impl_L0
                LDA     #0
_longptr_impl_L1
                TAY
                TSC
                CLC
                ADC     #arg_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
arg_FRAMESIZE   EQU     0
arg_STKGUARD    EQU     0
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
                LDA     #0
                STA     23,S   ; fccstk d=0 b=23
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                TYA
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                STZ     _fcc_long_hi
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
                LDA     #D
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                STZ     _fcc_long_hi
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
                BNE     *+5
                BRL     _longptr_impl_L2
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #1
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L2
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_long_hi
                AND     #$00FF
                STA     7,S   ; fccstk d=0 b=7
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L4
                LDA     #1
                BRL     _longptr_impl_L5
_longptr_impl_L4
                LDA     #0
_longptr_impl_L5
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L3
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #2
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L3
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                STA     G
                TAY
                LDA     _fcc_long_hi
                AND     #$00FF
                STA     G+2
                TYA
                SEP     #$20
                MX      %10
                LDA     G+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     G
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L7
                LDA     #1
                BRL     _longptr_impl_L8
_longptr_impl_L7
                LDA     #0
_longptr_impl_L8
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L6
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #4
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L6
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     23,S   ; fccstk d=2 b=21
                STA     _fcc_long_hi
                LDA     21,S   ; fccstk d=2 b=19
                TAY
                LDA     _fcc_ptr+2
                STA     _fcc_tmp_b
                TYA
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L10
                LDA     #1
                BRL     _longptr_impl_L11
_longptr_impl_L10
                LDA     #0
_longptr_impl_L11
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L9
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #8
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L9
                LDA     #GA
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     23,S   ; fccstk d=2 b=21
                STA     _fcc_long_hi
                LDA     21,S   ; fccstk d=2 b=19
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    GA+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    GA,X
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L13
                LDA     #1
                BRL     _longptr_impl_L14
_longptr_impl_L13
                LDA     #0
_longptr_impl_L14
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L12
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #16
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L12
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                STA     GS+2
                TAY
                LDA     _fcc_long_hi
                AND     #$00FF
                STA     GS+4
                TYA
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                LDA     GS+4
                STA     _fcc_fpr0+2
                LDA     GS+2
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L16
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L16
                LDA     #1
                BRL     _longptr_impl_L17
_longptr_impl_L16
                LDA     #0
_longptr_impl_L17
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L15
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #32
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L15
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_fpr0
                STA     15,S   ; fccstk d=0 b=15
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_long_hi
                SEP     #$20
                MX      %10
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L19
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L19
                LDA     #1
                BRL     _longptr_impl_L20
_longptr_impl_L19
                LDA     #0
_longptr_impl_L20
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L18
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #64
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L18
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     25,S   ; fccstk d=4 b=21
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=4 b=19
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     _fcc_long_hi
                SEP     #$20
                MX      %10
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL arg
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L22
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL ret
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _longptr_impl_L24
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _longptr_impl_L24
                LDA     #1
                BRL     _longptr_impl_L25
_longptr_impl_L24
                LDA     #0
_longptr_impl_L25
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L22
                LDA     #1
                BRL     _longptr_impl_L23
_longptr_impl_L22
                LDA     #0
_longptr_impl_L23
                CMP     #0
                BNE     *+5
                BRL     _longptr_impl_L21
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                TXA
                CLC
                ADC     #128
                STA     23,S   ; fccstk d=0 b=23
_longptr_impl_L21
                LDA     23,S   ; fccstk d=0 b=23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     36
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
