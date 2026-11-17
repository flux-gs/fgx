                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_array_elide.c
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
                LDA     #24
                PHA
                LDA     #8
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                CMP     #3
                BEQ     _struct_array_elide_L0
                LDA     _fcc_img0
                ORA     #1
                STA     _fcc_img0
_struct_array_elide_L0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #6
                LDA     [_fcc_fpr0],Y
                CMP     #10
                BNE     _struct_array_elide_L2
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #a
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
                BNE     _struct_array_elide_L2
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #119
                BEQ     _struct_array_elide_L1
_struct_array_elide_L2
                LDA     _fcc_img0
                TAX
                ORA     #2
                STA     _fcc_img0
_struct_array_elide_L1
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _struct_array_elide_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _struct_array_elide_L5
                LDA     #1
                BRA     _struct_array_elide_L6
_struct_array_elide_L5
                LDA     #0
_struct_array_elide_L6
                CMP     #0
                BNE     _struct_array_elide_L4
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                CMP     #0
                BNE     _struct_array_elide_L4
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #a
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
                CMP     #0
                BEQ     _struct_array_elide_L3
_struct_array_elide_L4
                LDA     _fcc_img0
                TAX
                ORA     #4
                STA     _fcc_img0
_struct_array_elide_L3
                LDA     #24
                PHA
                LDA     #8
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_divs16
                CMP     #3
                BEQ     _struct_array_elide_L7
                LDA     _fcc_img0
                ORA     #8
                STA     _fcc_img0
_struct_array_elide_L7
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                CMP     #121
                BNE     _struct_array_elide_L9
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #b
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
                CMP     #3
                BNE     _struct_array_elide_L9
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #6
                LDA     [_fcc_fpr0],Y
                CMP     #4
                BEQ     _struct_array_elide_L8
_struct_array_elide_L9
                LDA     _fcc_img0
                ORA     #16
                STA     _fcc_img0
_struct_array_elide_L8
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                CMP     #122
                BNE     _struct_array_elide_L11
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #6
                BEQ     _struct_array_elide_L10
_struct_array_elide_L11
                LDA     _fcc_img0
                TAX
                ORA     #32
                STA     _fcc_img0
_struct_array_elide_L10
                LDA     _fcc_img0
                BEQ     _struct_array_elide_L12
                LDA     _fcc_img0
                BRA     _struct_array_elide_L13
_struct_array_elide_L12
                LDA     #42
_struct_array_elide_L13
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
