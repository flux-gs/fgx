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
                CMP     #5
                BNE     _commast_L0
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CMP     #7
                BNE     _commast_L0
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                CLC
                ADC     #10
                STA     13,S   ; fccstk d=0 b=13
_commast_L0
                LDA     _tty+0
                TAX
                ORA     #2
                STA     _tty+0
                LDA     #1
                STA     _rawmode
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_tty
                STA     _fcc_fpr0
                PLA
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
                CMP     #10
                BNE     _commast_L1
                LDA     _rawmode
                TAX
                CMP     #1
                BNE     _commast_L1
                LDA     nxstty
                TAX
                CMP     #1
                BNE     _commast_L1
                LDA     seen_flags
                TAX
                CMP     #10
                BNE     _commast_L1
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                CLC
                ADC     #12
                STA     13,S   ; fccstk d=0 b=13
_commast_L1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_tty
                STA     _fcc_fpr0
                PLA
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
                CMP     #8
                BNE     _commast_L2
                LDA     _rawmode
                BNE     _commast_L2
                LDA     nxstty
                TAX
                CMP     #2
                BNE     _commast_L2
                LDA     seen_flags
                TAX
                CMP     #8
                BNE     _commast_L2
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                CLC
                ADC     #10
                STA     13,S   ; fccstk d=0 b=13
_commast_L2
                LDA     #4
                STA     gwin+0
                LDA     #6
                STA     gwin+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gwin
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                LDA     [_fcc_fpr0]
                STA     9,S   ; fccstk d=0 b=9
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     11,S   ; fccstk d=0 b=11
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #4
                BNE     _commast_L3
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #6
                BNE     _commast_L3
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                CLC
                ADC     #10
                STA     13,S   ; fccstk d=0 b=13
_commast_L3
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
