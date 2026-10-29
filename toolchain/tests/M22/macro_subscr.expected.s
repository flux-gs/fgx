                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from macro_subscr.c
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
                STA     _fcc_img0
_macro_subscr_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #128
                BVC     _macro_subscr_L3
                EOR     #$8000
_macro_subscr_L3
                BMI     *+5
                BRL     _macro_subscr_L2
                LDA     #up_tab
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                AND     #$00FF
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #lo_tab
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                AND     #$00FF
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
_macro_subscr_L1
                INC     _fcc_img0
                BRL     _macro_subscr_L0
_macro_subscr_L2
                LDA     #up_tab
                PHA
                LDA     #97
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #65
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #lo_tab
                PHA
                LDA     #65
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #sbuf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #sbuf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #65
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #sbuf
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #dbuf
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sbuf
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                INC
                STA     _fcc_img2
                LDA     _fcc_tmp_b
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     [_fcc_img4]
                INC     _fcc_img4
                AND     #$00FF
                TAX
                TXA
                AND     #255
                TAX
                LDA:    up_tab,X
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     #dbuf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                TAX
                LDA:    sbuf,X
                AND     #$00FF
                TAX
                TXA
                AND     #255
                TAX
                LDA:    lo_tab,X
                AND     #$00FF
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                TAX
                LDA:    dbuf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _macro_subscr_L4
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #20
                STA     _fcc_img1
_macro_subscr_L4
                LDA     #1
                TAX
                LDA:    dbuf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _macro_subscr_L5
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #22
                STA     _fcc_img1
_macro_subscr_L5
                LDA     _fcc_img1
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
                FGX2_RELOC_COUNT 2
