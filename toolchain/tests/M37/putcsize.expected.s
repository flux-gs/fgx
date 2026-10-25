                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from putcsize.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT put
put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #put_FRAMESIZE
                DO      put_STKGUARD
                BCC     put_stkovf
                CMP     _fcc_stkfloor
                BCS     put_stkok
put_stkovf       JMP     _fcc_stkoflow
                FIN
put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+put_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                DEC
                STA     [_fcc_fpr0]
                BMI     _putcsize_L0
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                DO      6+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                BRL     _putcsize_L1
_putcsize_L0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                AND     #128
                BNE     *+5
                BRL     _putcsize_L2
                LDA     [_fcc_fpr0]
                EOR     #$FFFF
                INC
                PHA
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _putcsize_L4
                EOR     #$8000
_putcsize_L4
                BMI     *+5
                BRL     _putcsize_L2
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
                DO      6+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                CMP     #10
                BEQ     _putcsize_L5
                DO      10+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+put_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
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
                STA     _fcc_fpr0+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BRA     _putcsize_L6
_putcsize_L5
                DO      10+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+put_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                FGX2_FARCALL _flsbuf
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
_putcsize_L6
                BRA     _putcsize_L3
_putcsize_L2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      10+put_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+put_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                AND     #$00FF
                PHA
                FGX2_FARCALL _flsbuf
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
_putcsize_L3
_putcsize_L1
                TAY
                TSC
                CLC
                ADC     #put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
put_FRAMESIZE   EQU     0
put_STKGUARD    EQU     0
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
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_ptr+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_ptr+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     #2
                STA     3,S   ; fccstk d=0 b=3
                LDA     #8
                STA     13,S   ; fccstk d=0 b=13
                LDA     #2
                STA     15,S   ; fccstk d=0 b=15
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
                LDA     #97
                PHA
                FGX2_FARCALL put
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #97
                BNE     _putcsize_L7
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
                LDA     #98
                PHA
                FGX2_FARCALL put
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #98
                BNE     _putcsize_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #20
                STA     1,S   ; fccstk d=0 b=1
_putcsize_L7
                LDA     #2
                TAX
                ORA     #128
                STA     15,S   ; fccstk d=0 b=15
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
                LDA     #99
                PHA
                FGX2_FARCALL put
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #99
                BNE     _putcsize_L8
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #$FFFF
                BNE     _putcsize_L8
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     #b
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _putcsize_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _putcsize_L9
                LDA     #1
                BRA     _putcsize_L10
_putcsize_L9
                LDA     #0
_putcsize_L10
                CMP     #0
                BEQ     _putcsize_L8
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #20
                STA     1,S   ; fccstk d=0 b=1
_putcsize_L8
                LDA     #0
                TAX
                LDA:    b,X
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _putcsize_L11
                LDA     #1
                TAX
                LDA:    b,X
                AND     #$00FF
                TAX
                CMP     #98
                BNE     _putcsize_L11
                LDA     #2
                TAX
                LDA:    b,X
                AND     #$00FF
                TAX
                CMP     #99
                BNE     _putcsize_L11
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_putcsize_L11
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
