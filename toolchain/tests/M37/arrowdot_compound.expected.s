                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrowdot_compound.c
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
                LDA     #g
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #43690
                STA     g+0
                LDA     #21845
                STA     g+6
                LDA     #255
                STA     g+2
                LDA     #4660
                STA     g+4
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #15
                STA     [_fcc_fpr0]
                LDA     g+2
                TAX
                TXA
                CMP     #15
                BEQ     *+5
                BRL     _arrowdot_compound_L5
                LDA     g+4
                TAX
                TXA
                CMP     #4660
                BEQ     *+5
                BRL     _arrowdot_compound_L5
                LDA     #1
                BRL     _arrowdot_compound_L6
_arrowdot_compound_L5
                LDA     #0
_arrowdot_compound_L6
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L3
                LDA     g+0
                TAX
                TXA
                CMP     #43690
                BEQ     *+5
                BRL     _arrowdot_compound_L3
                LDA     #1
                BRL     _arrowdot_compound_L4
_arrowdot_compound_L3
                LDA     #0
_arrowdot_compound_L4
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L1
                LDA     g+6
                TAX
                TXA
                CMP     #21845
                BEQ     *+5
                BRL     _arrowdot_compound_L1
                LDA     #1
                BRL     _arrowdot_compound_L2
_arrowdot_compound_L1
                LDA     #0
_arrowdot_compound_L2
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_arrowdot_compound_L0
                LDA     #4608
                STA     g+4
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                ORA     #52
                STA     [_fcc_fpr0]
                LDA     g+4
                TAX
                TXA
                CMP     #4660
                BEQ     *+5
                BRL     _arrowdot_compound_L12
                LDA     g+2
                TAX
                TXA
                CMP     #15
                BEQ     *+5
                BRL     _arrowdot_compound_L12
                LDA     #1
                BRL     _arrowdot_compound_L13
_arrowdot_compound_L12
                LDA     #0
_arrowdot_compound_L13
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L10
                LDA     g+0
                TAX
                TXA
                CMP     #43690
                BEQ     *+5
                BRL     _arrowdot_compound_L10
                LDA     #1
                BRL     _arrowdot_compound_L11
_arrowdot_compound_L10
                LDA     #0
_arrowdot_compound_L11
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L8
                LDA     g+6
                TAX
                TXA
                CMP     #21845
                BEQ     *+5
                BRL     _arrowdot_compound_L8
                LDA     #1
                BRL     _arrowdot_compound_L9
_arrowdot_compound_L8
                LDA     #0
_arrowdot_compound_L9
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L7
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_arrowdot_compound_L7
                LDA     #100
                STA     g+2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CLC
                ADC     #23
                STA     [_fcc_fpr0]
                LDA     g+2
                TAX
                TXA
                CMP     #123
                BEQ     *+5
                BRL     _arrowdot_compound_L19
                LDA     g+4
                TAX
                TXA
                CMP     #4660
                BEQ     *+5
                BRL     _arrowdot_compound_L19
                LDA     #1
                BRL     _arrowdot_compound_L20
_arrowdot_compound_L19
                LDA     #0
_arrowdot_compound_L20
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L17
                LDA     g+0
                TAX
                TXA
                CMP     #43690
                BEQ     *+5
                BRL     _arrowdot_compound_L17
                LDA     #1
                BRL     _arrowdot_compound_L18
_arrowdot_compound_L17
                LDA     #0
_arrowdot_compound_L18
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L15
                LDA     g+6
                TAX
                TXA
                CMP     #21845
                BEQ     *+5
                BRL     _arrowdot_compound_L15
                LDA     #1
                BRL     _arrowdot_compound_L16
_arrowdot_compound_L15
                LDA     #0
_arrowdot_compound_L16
                CMP     #0
                BNE     *+5
                BRL     _arrowdot_compound_L14
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_arrowdot_compound_L14
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
