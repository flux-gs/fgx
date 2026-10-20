                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from commast.c
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
                STA     13,S   ; fccstk d=0 b=13
                LDA     #3
                STA     _tty_ch
                LDA     #8
                STA     _tty+0
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                LDA     #5
                STA     5,S   ; fccstk d=0 b=5
                LDA     #7
                STA     7,S   ; fccstk d=0 b=7
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L1
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L1
                LDA     #1
                BRL     _commast_L2
_commast_L1
                LDA     #0
_commast_L2
                CMP     #0
                BNE     *+5
                BRL     _commast_L0
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
_commast_L0
                LDA     _tty+0
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     _tty+0
                LDA     #1
                STA     _rawmode
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_tty
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _tty_ch
                PHA
                FGX2_FARCALL xstty
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _tty+0
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L8
                LDA     _rawmode
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L8
                LDA     #1
                BRL     _commast_L9
_commast_L8
                LDA     #0
_commast_L9
                CMP     #0
                BNE     *+5
                BRL     _commast_L6
                LDA     nxstty
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L6
                LDA     #1
                BRL     _commast_L7
_commast_L6
                LDA     #0
_commast_L7
                CMP     #0
                BNE     *+5
                BRL     _commast_L4
                LDA     seen_flags
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L4
                LDA     #1
                BRL     _commast_L5
_commast_L4
                LDA     #0
_commast_L5
                CMP     #0
                BNE     *+5
                BRL     _commast_L3
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
_commast_L3
                LDA     _tty+0
                PHA
                LDA     #2
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     _tty+0
                LDA     #0
                STA     _rawmode
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_tty
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _tty_ch
                PHA
                FGX2_FARCALL xstty
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _tty+0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L15
                LDA     _rawmode
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L15
                LDA     #1
                BRL     _commast_L16
_commast_L15
                LDA     #0
_commast_L16
                CMP     #0
                BNE     *+5
                BRL     _commast_L13
                LDA     nxstty
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L13
                LDA     #1
                BRL     _commast_L14
_commast_L13
                LDA     #0
_commast_L14
                CMP     #0
                BNE     *+5
                BRL     _commast_L11
                LDA     seen_flags
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L11
                LDA     #1
                BRL     _commast_L12
_commast_L11
                LDA     #0
_commast_L12
                CMP     #0
                BNE     *+5
                BRL     _commast_L10
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
_commast_L10
                LDA     #4
                STA     gwin+0
                LDA     #6
                STA     gwin+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gwin
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     9,S   ; fccstk d=0 b=9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     11,S   ; fccstk d=0 b=11
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L18
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _commast_L18
                LDA     #1
                BRL     _commast_L19
_commast_L18
                LDA     #0
_commast_L19
                CMP     #0
                BNE     *+5
                BRL     _commast_L17
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
_commast_L17
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
                FGX2_EXPORT xstty
xstty            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #xstty_FRAMESIZE
                DO      xstty_STKGUARD
                BCC     xstty_stkovf
                CMP     _fcc_stkfloor
                BCS     xstty_stkok
xstty_stkovf       JMP     _fcc_stkoflow
                FIN
xstty_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     nxstty
                INC
                STA     nxstty
                DO      10+xstty_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+xstty_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+xstty_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+xstty_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+xstty_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+xstty_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     seen_flags
                DO      6+xstty_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+xstty_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+xstty_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #xstty_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
xstty_FRAMESIZE   EQU     0
xstty_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
