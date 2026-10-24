                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from derefparen.c
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
                LDA     #gs
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #120
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BEQ     *+5
                BRL     _derefparen_L1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
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
                LDA     #buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _derefparen_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _derefparen_L3
                LDA     #1
                BRL     _derefparen_L4
_derefparen_L3
                LDA     #0
_derefparen_L4
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L1
                LDA     #1
                BRL     _derefparen_L2
_derefparen_L1
                LDA     #0
_derefparen_L2
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #2
                STA     _fcc_img0
_derefparen_L0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #121
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ne16
                STA     _fcc_img1
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _derefparen_L8
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #121
                BEQ     *+5
                BRL     _derefparen_L8
                LDA     #1
                BRL     _derefparen_L9
_derefparen_L8
                LDA     #0
_derefparen_L9
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L6
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
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
                LDA     #buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _derefparen_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _derefparen_L10
                LDA     #1
                BRL     _derefparen_L11
_derefparen_L10
                LDA     #0
_derefparen_L11
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L6
                LDA     #1
                BRL     _derefparen_L7
_derefparen_L6
                LDA     #0
_derefparen_L7
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L5
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_derefparen_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #10
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ne16
                STA     _fcc_img1
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _derefparen_L13
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _derefparen_L13
                LDA     #1
                BRL     _derefparen_L14
_derefparen_L13
                LDA     #0
_derefparen_L14
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L12
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img0
_derefparen_L12
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #122
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
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
                LDA     #buf2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _derefparen_L18
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _derefparen_L18
                LDA     #1
                BRL     _derefparen_L19
_derefparen_L18
                LDA     #0
_derefparen_L19
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L16
                LDA     #0
                TAX
                LDA:    buf2,X
                AND     #$00FF
                TAX
                TXA
                CMP     #122
                BEQ     *+5
                BRL     _derefparen_L16
                LDA     #1
                BRL     _derefparen_L17
_derefparen_L16
                LDA     #0
_derefparen_L17
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L15
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #16
                STA     _fcc_img0
_derefparen_L15
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #119
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    buf2,X
                AND     #$00FF
                TAX
                TXA
                CMP     #119
                BEQ     *+5
                BRL     _derefparen_L21
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #buf2
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _derefparen_L23
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _derefparen_L23
                LDA     #1
                BRL     _derefparen_L24
_derefparen_L23
                LDA     #0
_derefparen_L24
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L21
                LDA     #1
                BRL     _derefparen_L22
_derefparen_L21
                LDA     #0
_derefparen_L22
                CMP     #0
                BNE     *+5
                BRL     _derefparen_L20
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #12
                STA     _fcc_img0
_derefparen_L20
                LDA     _fcc_img0
                TAX
                TXA
                CMP     #42
                BEQ     *+5
                BRL     _derefparen_L25
                LDA     #42
                BRL     _derefparen_L26
_derefparen_L25
                LDA     _fcc_img0
_derefparen_L26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
