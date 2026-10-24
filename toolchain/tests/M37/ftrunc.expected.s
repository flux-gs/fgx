                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ftrunc.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ftrunc_sizeof_path
_ftrunc_sizeof_path            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ftrunc_sizeof_path_FRAMESIZE
                DO      _ftrunc_sizeof_path_STKGUARD
                BCC     _ftrunc_sizeof_path_stkovf
                CMP     _fcc_stkfloor
                BCS     _ftrunc_sizeof_path_stkok
_ftrunc_sizeof_path_stkovf       JMP     _fcc_stkoflow
                FIN
_ftrunc_sizeof_path_stkok        TCS
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+_ftrunc_sizeof_path_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_ftrunc_sizeof_path_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_ftrunc_sizeof_path_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_ftrunc_sizeof_path_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ftrunc_sizeof_path_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ftrunc_sizeof_path_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL stat
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BPL     _ftrunc_L0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                TAY
                TSC
                CLC
                ADC     #_ftrunc_sizeof_path_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ftrunc_L0
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                TSC
                CLC
                ADC     #_ftrunc_sizeof_path_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ftrunc_sizeof_path_FRAMESIZE   EQU     52
_ftrunc_sizeof_path_STKGUARD    EQU     0
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
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #420
                PHA
                LDA     #2
                TAX
                ORA     #512
                TAX
                ORA     #1024
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ftrunc_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                BPL     _ftrunc_L1
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
_ftrunc_L1
                LDA     #10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ftrunc_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL write
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #10
                BEQ     _ftrunc_L2
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
_ftrunc_L2
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0004
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                PHA
                FGX2_FARCALL ftruncate
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                BNE     _ftrunc_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_ftrunc_L3
                LDA     #1
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL lseek
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     7,S   ; fccstk d=0 b=7
                TAY
                LDA     _fcc_long_hi
                STA     9,S   ; fccstk d=0 b=9
                TYA
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000A
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
                BEQ     _ftrunc_L4
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_ftrunc_L4
                LDA     #0
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL lseek
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _ftrunc_L5
                LDA     #32
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL read
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #4
                BNE     _ftrunc_L9
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _ftrunc_L9
                LDA     #1
                BRA     _ftrunc_L10
_ftrunc_L9
                LDA     #0
_ftrunc_L10
                CMP     #0
                BEQ     _ftrunc_L7
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #100
                BNE     _ftrunc_L7
                LDA     #1
                BRA     _ftrunc_L8
_ftrunc_L7
                LDA     #0
_ftrunc_L8
                CMP     #0
                BEQ     _ftrunc_L6
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_ftrunc_L6
_ftrunc_L5
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ftrunc_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ftrunc_sizeof_path
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0004
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
                BEQ     _ftrunc_L11
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_ftrunc_L11
                LDA     #2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ftrunc_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BPL     *+5
                BRL     _ftrunc_L12
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0009
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                PHA
                FGX2_FARCALL ftruncate
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                BNE     _ftrunc_L22
                LDA     #0
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL lseek
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ftrunc_L22
                LDA     #1
                BRA     _ftrunc_L23
_ftrunc_L22
                LDA     #0
_ftrunc_L23
                CMP     #0
                BEQ     _ftrunc_L20
                LDA     #32
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL read
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #9
                BNE     _ftrunc_L20
                LDA     #1
                BRA     _ftrunc_L21
_ftrunc_L20
                LDA     #0
_ftrunc_L21
                CMP     #0
                BEQ     _ftrunc_L18
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #100
                BNE     _ftrunc_L18
                LDA     #1
                BRA     _ftrunc_L19
_ftrunc_L18
                LDA     #0
_ftrunc_L19
                CMP     #0
                BEQ     _ftrunc_L16
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                PHA
                LDA     #4
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BNE     _ftrunc_L16
                LDA     #1
                BRA     _ftrunc_L17
_ftrunc_L16
                LDA     #0
_ftrunc_L17
                CMP     #0
                BEQ     _ftrunc_L14
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                PHA
                LDA     #8
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BNE     _ftrunc_L14
                LDA     #1
                BRA     _ftrunc_L15
_ftrunc_L14
                LDA     #0
_ftrunc_L15
                CMP     #0
                BEQ     _ftrunc_L13
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_ftrunc_L13
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
_ftrunc_L12
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
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
                LDA     #_ftrunc_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL truncate
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BNE     _ftrunc_L25
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ftrunc_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ftrunc_sizeof_path
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
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
                BEQ     _ftrunc_L25
                LDA     #1
                BRA     _ftrunc_L26
_ftrunc_L25
                LDA     #0
_ftrunc_L26
                CMP     #0
                BEQ     _ftrunc_L24
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ftrunc_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                BMI     _ftrunc_L27
                LDA     #0
                STA     errno
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                PHA
                FGX2_FARCALL ftruncate
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                BPL     _ftrunc_L29
                LDA     errno
                TAX
                CMP     #22
                BNE     _ftrunc_L29
                LDA     #1
                BRA     _ftrunc_L30
_ftrunc_L29
                LDA     #0
_ftrunc_L30
                CMP     #0
                BEQ     _ftrunc_L28
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_ftrunc_L28
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
_ftrunc_L27
_ftrunc_L24
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ftrunc_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     94
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 23
