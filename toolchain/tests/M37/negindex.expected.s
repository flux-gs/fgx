                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from negindex.c
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
_negindex_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #6
                BVC     _negindex_L3
                EOR     #$8000
_negindex_L3
                BMI     *+5
                BRL     _negindex_L2
                LDA     #_negindex_ai
                PHA
                LDA     _fcc_img0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #256
                CLC
                ADC     _fcc_img0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_negindex_ac
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #16
                CLC
                ADC     _fcc_img0
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
_negindex_L1
                INC     _fcc_img0
                BRL     _negindex_L0
_negindex_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_negindex_ai
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #$FFFF
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #257
                BNE     *+5
                BRL     _negindex_L4
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L4
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #$FFFE
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #256
                BNE     *+5
                BRL     _negindex_L5
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L5
                LDA     #$FFFF
                STA     _fcc_img1
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     _fcc_img1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #257
                BNE     *+5
                BRL     _negindex_L6
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L6
                LDA     #1
                STA     _fcc_img1
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     _fcc_img1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #259
                BNE     *+5
                BRL     _negindex_L7
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L7
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #259
                BNE     *+5
                BRL     _negindex_L8
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L8
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #258
                BNE     *+5
                BRL     _negindex_L9
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L9
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #1
                ASL
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #257
                BNE     *+5
                BRL     _negindex_L10
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L10
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #259
                BNE     *+5
                BRL     _negindex_L11
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L11
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #$FFFF
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #1911
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                LDA     #1
                ASL
                TAX
                LDA:    _negindex_ai,X
                TAX
                TXA
                CMP     #1911
                BNE     *+5
                BRL     _negindex_L12
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L12
                LDA     #0
                ASL
                TAX
                LDA:    _negindex_ai,X
                TAX
                TXA
                CMP     #256
                BNE     *+5
                BRL     _negindex_L13
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L13
                LDA     #2
                ASL
                TAX
                LDA:    _negindex_ai,X
                TAX
                TXA
                CMP     #258
                BNE     *+5
                BRL     _negindex_L14
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L14
                LDA     #_negindex_ai
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #257
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_negindex_ac
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_ptr+2
                LDA     _fcc_img4
                PHA
                LDA     #$FFFF
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #17
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _negindex_L15
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L15
                LDA     _fcc_img5
                STA     _fcc_ptr+2
                LDA     _fcc_img4
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #19
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _negindex_L16
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_negindex_L16
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
