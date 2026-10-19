                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from paren_base_chain.c
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     p
                LDA     _fcc_fpr0+2
                STA     p+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     t
                LDA     _fcc_fpr0+2
                STA     t+2
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #7
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #9
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     t+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     t
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     t+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     t
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     t
                LDA     _fcc_fpr0+2
                STA     t+2
                SEP     #$20
                MX      %10
                LDA     t+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     t
                STA     _fcc_fpr0
                LDA     #3
                LDY     #24
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     t
                LDA     _fcc_fpr0+2
                STA     t+2
                SEP     #$20
                MX      %10
                LDA     t+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     t
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _paren_base_chain_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _paren_base_chain_L1
                LDA     #1
                BRL     _paren_base_chain_L2
_paren_base_chain_L1
                LDA     #0
_paren_base_chain_L2
                CMP     #0
                BNE     *+5
                BRL     _paren_base_chain_L0
                LDA     _fcc_img0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L0
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _paren_base_chain_L3
                LDA     _fcc_img0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L3
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     #9
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _paren_base_chain_L4
                LDA     _fcc_img0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L4
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     t
                LDA     _fcc_fpr0+2
                STA     t+2
                SEP     #$20
                MX      %10
                LDA     t+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     t
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _paren_base_chain_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _paren_base_chain_L8
                LDA     #1
                BRL     _paren_base_chain_L9
_paren_base_chain_L8
                LDA     #0
_paren_base_chain_L9
                CMP     #0
                BNE     *+5
                BRL     _paren_base_chain_L6
                SEP     #$20
                MX      %10
                LDA     t+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     t
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _paren_base_chain_L6
                LDA     #1
                BRL     _paren_base_chain_L7
_paren_base_chain_L6
                LDA     #0
_paren_base_chain_L7
                CMP     #0
                BNE     *+5
                BRL     _paren_base_chain_L5
                LDA     _fcc_img0
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     t
                LDA     _fcc_fpr0+2
                STA     t+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _paren_base_chain_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _paren_base_chain_L11
                LDA     #1
                BRL     _paren_base_chain_L12
_paren_base_chain_L11
                LDA     #0
_paren_base_chain_L12
                CMP     #0
                BNE     *+5
                BRL     _paren_base_chain_L10
                LDA     _fcc_img0
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L10
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _paren_base_chain_L14
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _paren_base_chain_L14
                LDA     #1
                BRL     _paren_base_chain_L15
_paren_base_chain_L14
                LDA     #0
_paren_base_chain_L15
                CMP     #0
                BNE     *+5
                BRL     _paren_base_chain_L13
                LDA     _fcc_img0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L13
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _paren_base_chain_L17
                LDA     #1
                BRL     _paren_base_chain_L18
_paren_base_chain_L17
                LDA     #0
_paren_base_chain_L18
                CMP     #0
                BNE     *+5
                BRL     _paren_base_chain_L16
                LDA     _fcc_img0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _paren_base_chain_L20
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _paren_base_chain_L20
                LDA     #1
                BRL     _paren_base_chain_L21
_paren_base_chain_L20
                LDA     #0
_paren_base_chain_L21
                CMP     #0
                BNE     *+5
                BRL     _paren_base_chain_L19
                LDA     _fcc_img0
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_paren_base_chain_L19
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
