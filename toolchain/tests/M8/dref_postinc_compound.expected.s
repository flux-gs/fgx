                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dref_postinc_compound.c
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
                LDA     #bytes
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #193
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
                LDA     #bytes
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #194
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
                LDA     #bytes
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #131
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
                LDA     #bytes
                PHA
                LDA     #3
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bytes
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_dref_postinc_compound_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                INC
                STA     1,S   ; fccstk d=0 b=1
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                AND     #127
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                CMP     #0
                BEQ     _dref_postinc_compound_L1
                BRA     _dref_postinc_compound_L0
_dref_postinc_compound_L1
                LDA     #0
                TAX
                LDA:    bytes,X
                AND     #$00FF
                CMP     #65
                BNE     _dref_postinc_compound_L2
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_dref_postinc_compound_L2
                LDA     #1
                TAX
                LDA:    bytes,X
                AND     #$00FF
                CMP     #66
                BNE     _dref_postinc_compound_L3
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_dref_postinc_compound_L3
                LDA     #2
                TAX
                LDA:    bytes,X
                AND     #$00FF
                CMP     #3
                BNE     _dref_postinc_compound_L4
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_dref_postinc_compound_L4
                LDA     #words
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #words
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #words
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                INC
                INC
                STA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     [_fcc_fpr0]
                CLC
                ADC     #5
                STA     [_fcc_fpr0]
                CMP     #7
                BNE     _dref_postinc_compound_L5
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_dref_postinc_compound_L5
                LDA     #1
                ASL
                TAX
                LDA:    words,X
                CMP     #7
                BEQ     _dref_postinc_compound_L6
                LDA     _fcc_img0
                SEC
                SBC     #100
                STA     _fcc_img0
_dref_postinc_compound_L6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bytes
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    bytes,X
                AND     #$00FF
                TAX
                CMP     #32
                BNE     _dref_postinc_compound_L7
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_dref_postinc_compound_L7
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
