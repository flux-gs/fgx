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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     p
                LDA     _fcc_fpr0+2
                STA     p+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
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
                CLC
                ADC     #4
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_base_chain_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_base_chain_L1
                LDA     #1
                BRA     _paren_base_chain_L2
_paren_base_chain_L1
                LDA     #0
_paren_base_chain_L2
                CMP     #0
                BEQ     _paren_base_chain_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #5
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
                CMP     #7
                BNE     _paren_base_chain_L3
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #5
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
                CMP     #9
                BNE     _paren_base_chain_L4
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #5
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_base_chain_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_base_chain_L6
                LDA     #1
                BRA     _paren_base_chain_L7
_paren_base_chain_L6
                LDA     #0
_paren_base_chain_L7
                CMP     #0
                BEQ     _paren_base_chain_L5
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
                CMP     #3
                BNE     _paren_base_chain_L5
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_paren_base_chain_L5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
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
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_base_chain_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_base_chain_L9
                LDA     #1
                BRA     _paren_base_chain_L10
_paren_base_chain_L9
                LDA     #0
_paren_base_chain_L10
                CMP     #0
                BEQ     _paren_base_chain_L8
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_paren_base_chain_L8
                SEP     #$20
                MX      %10
                LDA     b+10
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     b+8
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_base_chain_L12
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_base_chain_L12
                LDA     #1
                BRA     _paren_base_chain_L13
_paren_base_chain_L12
                LDA     #0
_paren_base_chain_L13
                CMP     #0
                BEQ     _paren_base_chain_L11
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #5
                STA     _fcc_img0
_paren_base_chain_L11
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
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
                BEQ     _paren_base_chain_L15
                LDA     #1
                BRA     _paren_base_chain_L16
_paren_base_chain_L15
                LDA     #0
_paren_base_chain_L16
                CMP     #0
                BEQ     _paren_base_chain_L14
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #5
                STA     _fcc_img0
_paren_base_chain_L14
                SEP     #$20
                MX      %10
                LDA     b+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     b
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_base_chain_L18
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_base_chain_L18
                LDA     #1
                BRA     _paren_base_chain_L19
_paren_base_chain_L18
                LDA     #0
_paren_base_chain_L19
                CMP     #0
                BEQ     _paren_base_chain_L17
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #5
                STA     _fcc_img0
_paren_base_chain_L17
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
