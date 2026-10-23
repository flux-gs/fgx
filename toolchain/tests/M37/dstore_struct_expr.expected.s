                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dstore_struct_expr.c
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
                LDA     #4369
                STA     src+0
                LDA     #8738
                STA     src+2
                LDA     #13107
                STA     src+4
                LDA     #30583
                STA     after+0
                LDA     #30583
                STA     after+2
                LDA     #30583
                STA     after+4
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #dst
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_dstore_struct_expr_L0
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _dstore_struct_expr_L0
                LDA     dst+0
                TAX
                TXA
                CMP     #4369
                BEQ     *+5
                BRL     _dstore_struct_expr_L10
                LDA     dst+2
                TAX
                TXA
                CMP     #8738
                BEQ     *+5
                BRL     _dstore_struct_expr_L10
                LDA     #1
                BRL     _dstore_struct_expr_L11
_dstore_struct_expr_L10
                LDA     #0
_dstore_struct_expr_L11
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L8
                LDA     dst+4
                TAX
                TXA
                CMP     #13107
                BEQ     *+5
                BRL     _dstore_struct_expr_L8
                LDA     #1
                BRL     _dstore_struct_expr_L9
_dstore_struct_expr_L8
                LDA     #0
_dstore_struct_expr_L9
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L6
                LDA     after+0
                TAX
                TXA
                CMP     #30583
                BEQ     *+5
                BRL     _dstore_struct_expr_L6
                LDA     #1
                BRL     _dstore_struct_expr_L7
_dstore_struct_expr_L6
                LDA     #0
_dstore_struct_expr_L7
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L4
                LDA     after+2
                TAX
                TXA
                CMP     #30583
                BEQ     *+5
                BRL     _dstore_struct_expr_L4
                LDA     #1
                BRL     _dstore_struct_expr_L5
_dstore_struct_expr_L4
                LDA     #0
_dstore_struct_expr_L5
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L2
                LDA     after+4
                TAX
                TXA
                CMP     #30583
                BEQ     *+5
                BRL     _dstore_struct_expr_L2
                LDA     #1
                BRL     _dstore_struct_expr_L3
_dstore_struct_expr_L2
                LDA     #0
_dstore_struct_expr_L3
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_dstore_struct_expr_L1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #zero
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_dstore_struct_expr_L12
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _dstore_struct_expr_L12
                LDA     dst+0
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _dstore_struct_expr_L18
                LDA     dst+2
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _dstore_struct_expr_L18
                LDA     #1
                BRL     _dstore_struct_expr_L19
_dstore_struct_expr_L18
                LDA     #0
_dstore_struct_expr_L19
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L16
                LDA     dst+4
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _dstore_struct_expr_L16
                LDA     #1
                BRL     _dstore_struct_expr_L17
_dstore_struct_expr_L16
                LDA     #0
_dstore_struct_expr_L17
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L14
                LDA     after+0
                TAX
                TXA
                CMP     #30583
                BEQ     *+5
                BRL     _dstore_struct_expr_L14
                LDA     #1
                BRL     _dstore_struct_expr_L15
_dstore_struct_expr_L14
                LDA     #0
_dstore_struct_expr_L15
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L13
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_dstore_struct_expr_L13
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_dstore_struct_expr_L23
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _dstore_struct_expr_L23
                LDA     dst+2
                TAX
                TXA
                CMP     #8738
                BEQ     *+5
                BRL     _dstore_struct_expr_L21
                LDA     dst+4
                TAX
                TXA
                CMP     #13107
                BEQ     *+5
                BRL     _dstore_struct_expr_L21
                LDA     #1
                BRL     _dstore_struct_expr_L22
_dstore_struct_expr_L21
                LDA     #0
_dstore_struct_expr_L22
                CMP     #0
                BNE     *+5
                BRL     _dstore_struct_expr_L20
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_dstore_struct_expr_L20
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
