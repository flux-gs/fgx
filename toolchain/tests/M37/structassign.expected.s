                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from structassign.c
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
                LDA     #4660
                STA     src+0
                LDA     #22136
                STA     src+2
                LDA     #0
                STA     _fcc_img0
_structassign_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #7
                BVC     _structassign_L3
                EOR     #$8000
_structassign_L3
                BMI     *+5
                BRL     _structassign_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #src
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #$1111
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
_structassign_L1
                INC     _fcc_img0
                BRL     _structassign_L0
_structassign_L2
                LDA     #43981
                STA     src+32
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #dst
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
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
                LDY     #32
_structassign_L4
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structassign_L4
                LDA     dst+0
                TAX
                TXA
                CMP     #4660
                BNE     *+5
                BRL     _structassign_L5
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
_structassign_L5
                LDA     dst+2
                TAX
                TXA
                CMP     #22136
                BNE     *+5
                BRL     _structassign_L6
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
_structassign_L6
                LDA     #0
                STA     _fcc_img0
_structassign_L7
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #7
                BVC     _structassign_L10
                EOR     #$8000
_structassign_L10
                BMI     *+5
                BRL     _structassign_L9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #dst
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1111
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _structassign_L11
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
_structassign_L11
_structassign_L8
                INC     _fcc_img0
                BRL     _structassign_L7
_structassign_L9
                LDA     dst+32
                TAX
                TXA
                CMP     #43981
                BNE     *+5
                BRL     _structassign_L12
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
_structassign_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #src
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1111
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _structassign_L13
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L13
                LDA     src+32
                TAX
                TXA
                CMP     #43981
                BNE     *+5
                BRL     _structassign_L14
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L14
                LDA     #0
                STA     _fcc_img0
_structassign_L15
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #7
                BVC     _structassign_L18
                EOR     #$8000
_structassign_L18
                BMI     *+5
                BRL     _structassign_L17
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #dst
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
_structassign_L16
                INC     _fcc_img0
                BRL     _structassign_L15
_structassign_L17
                LDA     #0
                STA     dst+0
                LDA     #0
                STA     dst+32
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #src
                STA     sp
                LDA     _fcc_fpr0+2
                STA     sp+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #dst
                STA     dp
                LDA     _fcc_fpr0+2
                STA     dp+2
                SEP     #$20
                MX      %10
                LDA     dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     dp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     sp+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     sp
                STA     _fcc_fpr1
                LDY     #32
_structassign_L19
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structassign_L19
                SEP     #$20
                MX      %10
                LDA     dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     dp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #4660
                BNE     *+5
                BRL     _structassign_L20
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L20
                SEP     #$20
                MX      %10
                LDA     dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     dp
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #6
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1111
                STA     _fcc_long_hi
                LDA     #$0006
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _structassign_L21
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L21
                SEP     #$20
                MX      %10
                LDA     dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     dp
                STA     _fcc_fpr0
                LDY     #32
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #43981
                BNE     *+5
                BRL     _structassign_L22
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L22
                LDA     #90
                SEP     #$20
                MX      %10
                STA     fence
                REP     #$20
                MX      %00
                LDA     #1
                SEP     #$20
                MX      %10
                STA     osrc+0
                REP     #$20
                MX      %00
                LDA     #2
                SEP     #$20
                MX      %10
                STA     osrc+1
                REP     #$20
                MX      %00
                LDA     #3
                SEP     #$20
                MX      %10
                STA     osrc+2
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     odst+0
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     odst+1
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     odst+2
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #odst
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #osrc
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
_structassign_L23
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structassign_L23
                LDA     odst+0
                AND     #$00FF
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _structassign_L24
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L24
                LDA     odst+1
                AND     #$00FF
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _structassign_L25
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L25
                LDA     odst+2
                AND     #$00FF
                TAX
                TXA
                CMP     #3
                BNE     *+5
                BRL     _structassign_L26
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L26
                LDA     fence
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BNE     *+5
                BRL     _structassign_L27
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structassign_L27
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
