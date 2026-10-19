                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fileops.c
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fileops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL creat
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _fileops_L1
                EOR     #$8000
_fileops_L1
                BPL     *+5
                BRL     _fileops_L0
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L0
                LDA     #6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fileops_S1
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
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _fileops_L2
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _fileops_L3
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L3
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fileops_S0
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
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _fileops_L5
                EOR     #$8000
_fileops_L5
                BPL     *+5
                BRL     _fileops_L4
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L4
                LDA     #0
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
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
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
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
                BRL     _fileops_L6
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L6
                LDA     #4
                PHA
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
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _fileops_L7
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L7
                LDA     #4
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fileops_S2
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
                FGX2_FARCALL memcmp
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _fileops_L8
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L8
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fileops_S3
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
                PHA
                LDA     #1
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _fileops_L9
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fileops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _fileops_L10
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L10
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getwd
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _fileops_L11
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_fileops_L11
                LDA     3,S   ; fccstk d=0 b=3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     148
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 13
