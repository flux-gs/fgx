                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from elemdot_chain.c
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
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #11
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #22
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #22
                BEQ     *+5
                BRL     _elemdot_chain_L1
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _elemdot_chain_L1
                LDA     #1
                BRL     _elemdot_chain_L2
_elemdot_chain_L1
                LDA     #0
_elemdot_chain_L2
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_elemdot_chain_L0
                LDA     #1
                STA     _fcc_img1
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #33
                STA     [_fcc_fpr0]
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #44
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #44
                BEQ     *+5
                BRL     _elemdot_chain_L6
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #33
                BEQ     *+5
                BRL     _elemdot_chain_L6
                LDA     #1
                BRL     _elemdot_chain_L7
_elemdot_chain_L6
                LDA     #0
_elemdot_chain_L7
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L4
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #22
                BEQ     *+5
                BRL     _elemdot_chain_L4
                LDA     #1
                BRL     _elemdot_chain_L5
_elemdot_chain_L4
                LDA     #0
_elemdot_chain_L5
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_elemdot_chain_L3
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                INC
                INC
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                INC
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #47
                BEQ     *+5
                BRL     _elemdot_chain_L9
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #33
                BEQ     *+5
                BRL     _elemdot_chain_L9
                LDA     #1
                BRL     _elemdot_chain_L10
_elemdot_chain_L9
                LDA     #0
_elemdot_chain_L10
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L8
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_elemdot_chain_L8
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #65
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #67
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _elemdot_chain_L14
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _elemdot_chain_L14
                LDA     #1
                BRL     _elemdot_chain_L15
_elemdot_chain_L14
                LDA     #0
_elemdot_chain_L15
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L12
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #47
                BEQ     *+5
                BRL     _elemdot_chain_L12
                LDA     #1
                BRL     _elemdot_chain_L13
_elemdot_chain_L12
                LDA     #0
_elemdot_chain_L13
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L11
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_elemdot_chain_L11
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_dp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #55
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_dp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #66
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_dp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #77
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_dp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #77
                BEQ     *+5
                BRL     _elemdot_chain_L19
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_dp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #66
                BEQ     *+5
                BRL     _elemdot_chain_L19
                LDA     #1
                BRL     _elemdot_chain_L20
_elemdot_chain_L19
                LDA     #0
_elemdot_chain_L20
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L17
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_dp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #55
                BEQ     *+5
                BRL     _elemdot_chain_L17
                LDA     #1
                BRL     _elemdot_chain_L18
_elemdot_chain_L17
                LDA     #0
_elemdot_chain_L18
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L16
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_elemdot_chain_L16
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #_elemdot_chain_valstack
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #88
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #_elemdot_chain_valstack
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #99
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_valstack
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #100
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #_elemdot_chain_valstack
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _elemdot_chain_L24
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #_elemdot_chain_valstack
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #88
                BEQ     *+5
                BRL     _elemdot_chain_L24
                LDA     #1
                BRL     _elemdot_chain_L25
_elemdot_chain_L24
                LDA     #0
_elemdot_chain_L25
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L22
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     #_elemdot_chain_valstack
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #100
                BEQ     *+5
                BRL     _elemdot_chain_L22
                LDA     #1
                BRL     _elemdot_chain_L23
_elemdot_chain_L22
                LDA     #0
_elemdot_chain_L23
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L21
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_elemdot_chain_L21
                LDA     #123
                STA     _elemdot_chain_src+0
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #121
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_elemdot_chain_src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_elemdot_chain_L26
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _elemdot_chain_L26
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #123
                BEQ     *+5
                BRL     _elemdot_chain_L28
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #_elemdot_chain_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #121
                BEQ     *+5
                BRL     _elemdot_chain_L28
                LDA     #1
                BRL     _elemdot_chain_L29
_elemdot_chain_L28
                LDA     #0
_elemdot_chain_L29
                CMP     #0
                BNE     *+5
                BRL     _elemdot_chain_L27
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_elemdot_chain_L27
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
