                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libcadds.c
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
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL labs
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
                LDA     #$0005
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
                BRL     _libcadds_L3
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL labs
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
                LDA     #$0005
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
                BRL     _libcadds_L3
                LDA     #1
                BRL     _libcadds_L4
_libcadds_L3
                LDA     #0
_libcadds_L4
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL labs
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
                BRL     _libcadds_L1
                LDA     #1
                BRL     _libcadds_L2
_libcadds_L1
                LDA     #0
_libcadds_L2
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S1
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
                LDA     #_libcadds_S0
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fwrite
                TSC
                CLC
                ADC     #12
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S0
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
                STA     7,S   ; fccstk d=0 b=7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=4 b=7
                PHA
                FGX2_FARCALL fdopen
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _libcadds_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _libcadds_L7
                LDA     #0
                BRL     _libcadds_L8
_libcadds_L7
                LDA     #1
_libcadds_L8
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     #1
                PHA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BRL     _libcadds_L6
_libcadds_L5
                LDA     #$FFFF
_libcadds_L6
                STA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _libcadds_L12
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _libcadds_L12
                LDA     #1
                BRL     _libcadds_L13
_libcadds_L12
                LDA     #0
_libcadds_L13
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L10
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _libcadds_L10
                LDA     #1
                BRL     _libcadds_L11
_libcadds_L10
                LDA     #0
_libcadds_L11
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L9
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _libcadds_L15
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _libcadds_L15
                LDA     #0
                BRL     _libcadds_L16
_libcadds_L15
                LDA     #1
_libcadds_L16
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L14
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _libcadds_L17
_libcadds_L14
                LDA     7,S   ; fccstk d=0 b=7
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
_libcadds_L17
                LDA     #0
                PHA
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S0
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
                STA     7,S   ; fccstk d=0 b=7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=4 b=7
                PHA
                FGX2_FARCALL fdopen
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _libcadds_L19
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _libcadds_L19
                LDA     #0
                BRL     _libcadds_L20
_libcadds_L19
                LDA     #1
_libcadds_L20
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L18
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fwrite
                TSC
                CLC
                ADC     #12
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _libcadds_L21
_libcadds_L18
                LDA     7,S   ; fccstk d=0 b=7
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
_libcadds_L21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S3
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
                LDA     #_libcadds_S0
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #8
                PHA
                LDA     #1
                PHA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     11,S   ; fccstk d=0 b=11
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _libcadds_L25
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _libcadds_L25
                LDA     #1
                BRL     _libcadds_L26
_libcadds_L25
                LDA     #0
_libcadds_L26
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L23
                LDA     #3
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #100
                BEQ     *+5
                BRL     _libcadds_L23
                LDA     #1
                BRL     _libcadds_L24
_libcadds_L23
                LDA     #0
_libcadds_L24
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L22
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L22
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libcadds_S3
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
                LDA     #_libcadds_S0
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _libcadds_L32
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #90
                PHA
                FGX2_FARCALL ungetc
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _libcadds_L32
                LDA     #1
                BRL     _libcadds_L33
_libcadds_L32
                LDA     #0
_libcadds_L33
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L30
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _libcadds_L30
                LDA     #1
                BRL     _libcadds_L31
_libcadds_L30
                LDA     #0
_libcadds_L31
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L28
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #98
                BEQ     *+5
                BRL     _libcadds_L28
                LDA     #1
                BRL     _libcadds_L29
_libcadds_L28
                LDA     #0
_libcadds_L29
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L27
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L27
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                LDA     #_libcadds_S3
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
                LDA     #_libcadds_S0
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_libcadds_L34
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #0
_libcadds_L36
                BPL     *+5
                BRL     _libcadds_L35
                BRL     _libcadds_L34
_libcadds_L35
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #81
                PHA
                FGX2_FARCALL ungetc
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                TXA
                CMP     #81
                BEQ     *+5
                BRL     _libcadds_L38
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #81
                BEQ     *+5
                BRL     _libcadds_L38
                LDA     #1
                BRL     _libcadds_L39
_libcadds_L38
                LDA     #0
_libcadds_L39
                CMP     #0
                BNE     *+5
                BRL     _libcadds_L37
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L37
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                LDA     #_libcadds_S0
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 33
