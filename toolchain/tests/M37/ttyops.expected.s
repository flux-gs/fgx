                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ttyops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT onint
onint            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #onint_FRAMESIZE
                DO      onint_STKGUARD
                BCC     onint_stkovf
                CMP     _fcc_stkfloor
                BCS     onint_stkok
onint_stkovf       JMP     _fcc_stkoflow
                FIN
onint_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     hits
                TAX
                TXA
                INC
                STA     hits
                TAY
                TSC
                CLC
                ADC     #onint_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
onint_FRAMESIZE   EQU     0
onint_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sgbuf
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                FGX2_FARCALL gtty
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _ttyops_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_ttyops_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sgbuf
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                FGX2_FARCALL stty
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _ttyops_L1
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_ttyops_L1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sgbuf
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #29704
                PHA
                LDA     #99
                PHA
                FGX2_FARCALL ioctl
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #$FFFF
                BEQ     *+5
                BRL     _ttyops_L2
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_ttyops_L2
                SEP     #$20
                MX      %10
                LDA     _ttyops_FA4+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _ttyops_FA4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                FGX2_FARCALL signal
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ttyops_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ttyops_L5
                LDA     #1
                BRL     _ttyops_L6
_ttyops_L5
                LDA     #0
_ttyops_L6
                CMP     #0
                BNE     *+5
                BRL     _ttyops_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_ttyops_L3
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                FGX2_FARCALL signal
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
                BRL     _ttyops_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ttyops_L8
                LDA     #0
                BRL     _ttyops_L9
_ttyops_L8
                LDA     #1
_ttyops_L9
                CMP     #0
                BNE     *+5
                BRL     _ttyops_L7
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_ttyops_L7
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                FGX2_FARCALL signal
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ttyops_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ttyops_L11
                LDA     #1
                BRL     _ttyops_L12
_ttyops_L11
                LDA     #0
_ttyops_L12
                CMP     #0
                BNE     *+5
                BRL     _ttyops_L10
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #3
                STA     5,S   ; fccstk d=0 b=5
_ttyops_L10
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                FGX2_FARCALL signal
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _ttyops_L14
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _ttyops_L14
                LDA     #1
                BRL     _ttyops_L15
_ttyops_L14
                LDA     #0
_ttyops_L15
                CMP     #0
                BNE     *+5
                BRL     _ttyops_L13
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #3
                STA     5,S   ; fccstk d=0 b=5
_ttyops_L13
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
