                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from stdioops.c
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_stdioops_S1
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
                LDA     #_stdioops_S0
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
                BNE     _stdioops_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _stdioops_L1
                LDA     #0
                BRA     _stdioops_L2
_stdioops_L1
                LDA     #1
_stdioops_L2
                CMP     #0
                BEQ     _stdioops_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #5
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_stdioops_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fputs
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BMI     _stdioops_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L3
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #88
                PHA
                FGX2_FARCALL fputc
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #88
                BNE     _stdioops_L4
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L4
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     #_stdioops_S3
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
                LDA     #_stdioops_S0
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
                BNE     _stdioops_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _stdioops_L6
                LDA     #0
                BRA     _stdioops_L7
_stdioops_L6
                LDA     #1
_stdioops_L7
                CMP     #0
                BNE     *+5
                BRL     _stdioops_L5
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgets
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _stdioops_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _stdioops_L8
                LDA     #0
                BRA     _stdioops_L9
_stdioops_L8
                LDA     #1
_stdioops_L9
                CMP     #0
                BEQ     _stdioops_L5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #104
                BNE     _stdioops_L5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #5
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #10
                BNE     _stdioops_L5
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #5
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L5
                LDY     #14
                LDA     [_fcc_img16],Y
                AND     #$00FF
                TAX
                SEC
                SBC     #3
                BVC     _stdioops_L11
                EOR     #$8000
_stdioops_L11
                BMI     _stdioops_L10
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L10
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                CMP     #88
                BNE     _stdioops_L12
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L12
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #$FFFF
                BNE     _stdioops_L13
                LDY     #12
                LDA     [_fcc_img16],Y
                AND     #16
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ne16
                CMP     #0
                BEQ     _stdioops_L13
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L13
                LDA     #0
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fseek
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     _stdioops_L14
                LDY     #12
                LDA     [_fcc_img16],Y
                AND     #16
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ne16
                CMP     #0
                BNE     _stdioops_L14
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                CMP     #101
                BNE     _stdioops_L14
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL ftell
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDX     #2
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _stdioops_L14
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L14
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     #_stdioops_S1
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
                LDA     #_stdioops_S0
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_stdioops_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fputs
                TSC
                CLC
                ADC     #8
                TCS
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     #_stdioops_S3
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
                LDA     #_stdioops_S0
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #32
                PHA
                LDA     #1
                PHA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     7,S   ; fccstk d=0 b=7
                TAX
                CMP     #2
                BNE     _stdioops_L15
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_stdioops_S5
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
                LDA     #_stdioops_S0
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _stdioops_L17
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _stdioops_L17
                LDA     #1
                BRA     _stdioops_L18
_stdioops_L17
                LDA     #0
_stdioops_L18
                CMP     #0
                BEQ     _stdioops_L16
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_stdioops_L16
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
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
                LDA     #_stdioops_S0
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
main_FRAMESIZE   EQU     44
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 22
