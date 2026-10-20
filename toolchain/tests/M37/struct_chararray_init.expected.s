                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_chararray_init.c
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
                LDA     braced+0
                TAX
                LDA     #4369
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L9
                LDA     braced+6
                TAX
                LDA     #8738
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L9
                LDA     #1
                BRL     _struct_chararray_init_L10
_struct_chararray_init_L9
                LDA     #0
_struct_chararray_init_L10
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #braced
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L7
                LDA     #1
                BRL     _struct_chararray_init_L8
_struct_chararray_init_L7
                LDA     #0
_struct_chararray_init_L8
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #braced
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #66
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L5
                LDA     #1
                BRL     _struct_chararray_init_L6
_struct_chararray_init_L5
                LDA     #0
_struct_chararray_init_L6
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #braced
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L3
                LDA     #1
                BRL     _struct_chararray_init_L4
_struct_chararray_init_L3
                LDA     #0
_struct_chararray_init_L4
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #braced
                INC
                INC
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #68
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L1
                LDA     #1
                BRL     _struct_chararray_init_L2
_struct_chararray_init_L1
                LDA     #0
_struct_chararray_init_L2
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L0
                LDA     _fcc_img0
                TAX
                LDA     #14
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_struct_chararray_init_L0
                LDA     shortb+0
                TAX
                LDA     #13107
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L20
                LDA     shortb+6
                TAX
                LDA     #17476
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L20
                LDA     #1
                BRL     _struct_chararray_init_L21
_struct_chararray_init_L20
                LDA     #0
_struct_chararray_init_L21
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L18
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #shortb
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #88
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L18
                LDA     #1
                BRL     _struct_chararray_init_L19
_struct_chararray_init_L18
                LDA     #0
_struct_chararray_init_L19
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #shortb
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L16
                LDA     #1
                BRL     _struct_chararray_init_L17
_struct_chararray_init_L16
                LDA     #0
_struct_chararray_init_L17
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L14
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #shortb
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L14
                LDA     #1
                BRL     _struct_chararray_init_L15
_struct_chararray_init_L14
                LDA     #0
_struct_chararray_init_L15
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #shortb
                INC
                INC
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L12
                LDA     #1
                BRL     _struct_chararray_init_L13
_struct_chararray_init_L12
                LDA     #0
_struct_chararray_init_L13
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L11
                LDA     _fcc_img0
                TAX
                LDA     #14
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_struct_chararray_init_L11
                LDA     fromstr+0
                TAX
                LDA     #21845
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L39
                LDA     fromstr+6
                TAX
                LDA     #26214
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L39
                LDA     #1
                BRL     _struct_chararray_init_L40
_struct_chararray_init_L39
                LDA     #0
_struct_chararray_init_L40
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L37
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fromstr
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #104
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L37
                LDA     #1
                BRL     _struct_chararray_init_L38
_struct_chararray_init_L37
                LDA     #0
_struct_chararray_init_L38
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L35
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fromstr
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #105
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L35
                LDA     #1
                BRL     _struct_chararray_init_L36
_struct_chararray_init_L35
                LDA     #0
_struct_chararray_init_L36
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L33
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fromstr
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L33
                LDA     #1
                BRL     _struct_chararray_init_L34
_struct_chararray_init_L33
                LDA     #0
_struct_chararray_init_L34
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #fromstr
                INC
                INC
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L31
                LDA     #1
                BRL     _struct_chararray_init_L32
_struct_chararray_init_L31
                LDA     #0
_struct_chararray_init_L32
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L29
                LDA     exact+0
                TAX
                LDA     #30583
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L29
                LDA     #1
                BRL     _struct_chararray_init_L30
_struct_chararray_init_L29
                LDA     #0
_struct_chararray_init_L30
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L27
                LDA     exact+6
                TAX
                LDA     #4660
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L27
                LDA     #1
                BRL     _struct_chararray_init_L28
_struct_chararray_init_L27
                LDA     #0
_struct_chararray_init_L28
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L25
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #exact
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #97
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L25
                LDA     #1
                BRL     _struct_chararray_init_L26
_struct_chararray_init_L25
                LDA     #0
_struct_chararray_init_L26
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L23
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #exact
                INC
                INC
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #100
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _struct_chararray_init_L23
                LDA     #1
                BRL     _struct_chararray_init_L24
_struct_chararray_init_L23
                LDA     #0
_struct_chararray_init_L24
                CMP     #0
                BNE     *+5
                BRL     _struct_chararray_init_L22
                LDA     _fcc_img0
                TAX
                LDA     #14
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_struct_chararray_init_L22
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
