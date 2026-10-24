                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_fcc_fp_dbl.c
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
                STA     _fcc_img0
_p33_fcc_fp_dbl_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #520
                BVC     _p33_fcc_fp_dbl_L3
                EOR     #$8000
_p33_fcc_fp_dbl_L3
                BMI     *+5
                BRL     _p33_fcc_fp_dbl_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
_p33_fcc_fp_dbl_L1
                INC     _fcc_img0
                BRL     _p33_fcc_fp_dbl_L0
_p33_fcc_fp_dbl_L2
                LDA     #100
                PHA
                TSC
                CLC
                ADC     #527
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     #200
                PHA
                TSC
                CLC
                ADC     #529
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TSC
                CLC
                ADC     #525
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                PHA
                TSC
                CLC
                ADC     #529
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                TSC
                CLC
                ADC     #531
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TSC
                CLC
                ADC     #529
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #300
                BNE     *+5
                BRL     _p33_fcc_fp_dbl_L4
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
_p33_fcc_fp_dbl_L4
                TSC
                CLC
                ADC     #525
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ASL
                PHA
                TSC
                CLC
                ADC     #529
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                TSC
                CLC
                ADC     #531
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TSC
                CLC
                ADC     #529
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #800
                BNE     *+5
                BRL     _p33_fcc_fp_dbl_L5
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
_p33_fcc_fp_dbl_L5
                TSC
                CLC
                ADC     #529
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                PHA
                TSC
                CLC
                ADC     #529
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                PHA
                TSC
                CLC
                ADC     #527
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                TSC
                CLC
                ADC     #525
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #800
                BEQ     *+5
                BRL     _p33_fcc_fp_dbl_L7
                TSC
                CLC
                ADC     #527
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                TAX
                TXA
                CMP     #800
                BEQ     *+5
                BRL     _p33_fcc_fp_dbl_L7
                LDA     #0
                BRL     _p33_fcc_fp_dbl_L8
_p33_fcc_fp_dbl_L7
                LDA     #1
_p33_fcc_fp_dbl_L8
                CMP     #0
                BNE     *+5
                BRL     _p33_fcc_fp_dbl_L6
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
_p33_fcc_fp_dbl_L6
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #0
                BEQ     *+5
                BRL     _p33_fcc_fp_dbl_L12
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                CMP     #0
                BEQ     *+5
                BRL     _p33_fcc_fp_dbl_L12
                LDA     #0
                BRL     _p33_fcc_fp_dbl_L13
_p33_fcc_fp_dbl_L12
                LDA     #1
_p33_fcc_fp_dbl_L13
                CMP     #0
                BEQ     *+5
                BRL     _p33_fcc_fp_dbl_L10
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                INC
                INC
                CLC
                ADC     #519
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                CMP     #0
                BEQ     *+5
                BRL     _p33_fcc_fp_dbl_L10
                LDA     #0
                BRL     _p33_fcc_fp_dbl_L11
_p33_fcc_fp_dbl_L10
                LDA     #1
_p33_fcc_fp_dbl_L11
                CMP     #0
                BNE     *+5
                BRL     _p33_fcc_fp_dbl_L9
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
_p33_fcc_fp_dbl_L9
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
main_FRAMESIZE   EQU     530
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 2
