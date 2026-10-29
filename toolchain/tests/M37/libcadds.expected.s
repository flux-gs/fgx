                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libcadds.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
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
                PLY
                PLY
                LDX     #5
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _libcadds_L0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL labs
                PLY
                PLY
                LDX     #5
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _libcadds_L0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL labs
                PLY
                PLY
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _libcadds_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
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
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                PLY
                PLY
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
                PLY
                PLY
                PLY
                PLY
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
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _libcadds_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _libcadds_L3
                LDA     #0
                BRA     _libcadds_L4
_libcadds_L3
                LDA     #1
_libcadds_L4
                CMP     #0
                BEQ     _libcadds_L1
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                BRA     _libcadds_L2
_libcadds_L1
                LDA     #$FFFF
_libcadds_L2
                STA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #3
                BNE     _libcadds_L5
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _libcadds_L5
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #99
                BNE     _libcadds_L5
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L5
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _libcadds_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _libcadds_L7
                LDA     #0
                BRA     _libcadds_L8
_libcadds_L7
                LDA     #1
_libcadds_L8
                CMP     #0
                BEQ     _libcadds_L6
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                PLY
                PLY
                BRA     _libcadds_L9
_libcadds_L6
                LDA     7,S   ; fccstk d=0 b=7
                PHA
                FGX2_FARCALL close
                PLY
_libcadds_L9
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
                PLY
                PLY
                PLY
                PLY
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
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _libcadds_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _libcadds_L11
                LDA     #0
                BRA     _libcadds_L12
_libcadds_L11
                LDA     #1
_libcadds_L12
                CMP     #0
                BEQ     _libcadds_L10
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                PLY
                PLY
                BRA     _libcadds_L13
_libcadds_L10
                LDA     7,S   ; fccstk d=0 b=7
                PHA
                FGX2_FARCALL close
                PLY
_libcadds_L13
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
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                PLY
                PLY
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #4
                BNE     _libcadds_L14
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _libcadds_L14
                LDA     #3
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #100
                BNE     _libcadds_L14
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L14
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
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                PLY
                PLY
                STA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #97
                BNE     _libcadds_L15
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #90
                PHA
                FGX2_FARCALL ungetc
                PLY
                PLY
                PLY
                TAX
                CMP     #90
                BNE     _libcadds_L15
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                PLY
                PLY
                TAX
                CMP     #90
                BNE     _libcadds_L15
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                PLY
                PLY
                TAX
                CMP     #98
                BNE     _libcadds_L15
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L15
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                PLY
                PLY
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
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
_libcadds_L16
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                PLY
                PLY
                CMP     #0
                BMI     _libcadds_L17
                BRA     _libcadds_L16
_libcadds_L17
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #81
                PHA
                FGX2_FARCALL ungetc
                PLY
                PLY
                PLY
                TAX
                CMP     #81
                BNE     _libcadds_L18
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                PLY
                PLY
                TAX
                CMP     #81
                BNE     _libcadds_L18
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_libcadds_L18
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                PLY
                PLY
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
                PLY
                PLY
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 33
