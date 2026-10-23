                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_farfield.c
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
                LDA     #17
                STA     1,S   ; fccstk d=0 b=1
                LDA     #34
                PHA
                TSC
                CLC
                ADC     #261
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     #51
                PHA
                TSC
                CLC
                ADC     #263
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #7
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #255
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #9
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #17
                BNE     *+5
                BRL     _p33_farfield_L0
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
_p33_farfield_L0
                TSC
                CLC
                ADC     #259
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #34
                BNE     *+5
                BRL     _p33_farfield_L1
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
_p33_farfield_L1
                TSC
                CLC
                ADC     #261
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #51
                BNE     *+5
                BRL     _p33_farfield_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_farfield_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #7
                BNE     *+5
                BRL     _p33_farfield_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_farfield_L3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #255
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #9
                BNE     *+5
                BRL     _p33_farfield_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_farfield_L4
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     262
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 2
