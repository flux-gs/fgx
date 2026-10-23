                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_init_leaves.c
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
                LDA     _struct_init_leaves_zru+2
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L1
                LDA     _struct_init_leaves_zru+6
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0002
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L1
                LDA     #1
                BRL     _struct_init_leaves_L2
_struct_init_leaves_L1
                LDA     #0
_struct_init_leaves_L2
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_struct_init_leaves_L0
                LDA     _struct_init_leaves_zru+10
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L4
                LDA     _struct_init_leaves_zru+14
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+12
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0004
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L4
                LDA     #1
                BRL     _struct_init_leaves_L5
_struct_init_leaves_L4
                LDA     #0
_struct_init_leaves_L5
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_struct_init_leaves_L3
                LDA     _struct_init_leaves_zru+18
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+16
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0005
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L7
                LDA     _struct_init_leaves_zru+20
                TAX
                TXA
                CMP     #6
                BEQ     *+5
                BRL     _struct_init_leaves_L7
                LDA     #1
                BRL     _struct_init_leaves_L8
_struct_init_leaves_L7
                LDA     #0
_struct_init_leaves_L8
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L6
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_struct_init_leaves_L6
                LDA     _struct_init_leaves_part+2
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0007
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L10
                LDA     _struct_init_leaves_part+6
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L10
                LDA     #1
                BRL     _struct_init_leaves_L11
_struct_init_leaves_L10
                LDA     #0
_struct_init_leaves_L11
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L9
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img0
_struct_init_leaves_L9
                LDA     _struct_init_leaves_part+10
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0008
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L13
                LDA     _struct_init_leaves_part+14
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+12
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L13
                LDA     #1
                BRL     _struct_init_leaves_L14
_struct_init_leaves_L13
                LDA     #0
_struct_init_leaves_L14
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L12
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img0
_struct_init_leaves_L12
                LDA     _struct_init_leaves_nulv+2
                STA     _fcc_fpr0+2
                LDA     _struct_init_leaves_nulv+0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nv
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _struct_init_leaves_L18
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _struct_init_leaves_L18
                LDA     #1
                BRL     _struct_init_leaves_L19
_struct_init_leaves_L18
                LDA     #0
_struct_init_leaves_L19
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L16
                LDA     _struct_init_leaves_nulv+6
                STA     _fcc_fpr0+2
                LDA     _struct_init_leaves_nulv+4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nm
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _struct_init_leaves_L20
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _struct_init_leaves_L20
                LDA     #1
                BRL     _struct_init_leaves_L21
_struct_init_leaves_L20
                LDA     #0
_struct_init_leaves_L21
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L16
                LDA     #1
                BRL     _struct_init_leaves_L17
_struct_init_leaves_L16
                LDA     #0
_struct_init_leaves_L17
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L15
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_struct_init_leaves_L15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_struct_init_leaves_nulv
                CLC
                ADC     #8
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _struct_init_leaves_L29
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _struct_init_leaves_L29
                LDA     #1
                BRL     _struct_init_leaves_L30
_struct_init_leaves_L29
                LDA     #0
_struct_init_leaves_L30
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L27
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_struct_init_leaves_nulv
                CLC
                ADC     #8
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
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _struct_init_leaves_L31
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _struct_init_leaves_L31
                LDA     #1
                BRL     _struct_init_leaves_L32
_struct_init_leaves_L31
                LDA     #0
_struct_init_leaves_L32
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L27
                LDA     #1
                BRL     _struct_init_leaves_L28
_struct_init_leaves_L27
                LDA     #0
_struct_init_leaves_L28
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L25
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_struct_init_leaves_nulv
                CLC
                ADC     #8
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
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _struct_init_leaves_L33
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _struct_init_leaves_L33
                LDA     #1
                BRL     _struct_init_leaves_L34
_struct_init_leaves_L33
                LDA     #0
_struct_init_leaves_L34
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L25
                LDA     #1
                BRL     _struct_init_leaves_L26
_struct_init_leaves_L25
                LDA     #0
_struct_init_leaves_L26
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L23
                LDA     _struct_init_leaves_nulv+20
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _struct_init_leaves_L23
                LDA     #1
                BRL     _struct_init_leaves_L24
_struct_init_leaves_L23
                LDA     #0
_struct_init_leaves_L24
                CMP     #0
                BNE     *+5
                BRL     _struct_init_leaves_L22
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img0
_struct_init_leaves_L22
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
