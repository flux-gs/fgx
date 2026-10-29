                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from init_nested.c
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
                LDA     a+0
                CMP     #1
                BNE     _init_nested_L1
                LDA     a+2
                CMP     #2
                BNE     _init_nested_L1
                LDA     a+4
                CMP     #3
                BNE     _init_nested_L1
                LDA     a+6
                CMP     #4
                BNE     _init_nested_L1
                LDA     a+8
                CMP     #5
                BEQ     _init_nested_L0
_init_nested_L1
                INC     _fcc_img0
_init_nested_L0
                LDA     b+2
                CMP     #2
                BNE     _init_nested_L3
                LDA     b+4
                CMP     #3
                BNE     _init_nested_L3
                LDA     b+6
                CMP     #4
                BNE     _init_nested_L3
                LDA     b+8
                CMP     #5
                BEQ     _init_nested_L2
_init_nested_L3
                INC     _fcc_img0
_init_nested_L2
                LDA     c+0
                CMP     #1
                BNE     _init_nested_L5
                LDA     c+2
                CMP     #2
                BNE     _init_nested_L5
                LDA     c+4
                BNE     _init_nested_L5
                LDA     c+6
                BNE     _init_nested_L5
                LDA     c+8
                BEQ     _init_nested_L4
_init_nested_L5
                INC     _fcc_img0
_init_nested_L4
                LDA     g+6
                CMP     #3
                BNE     _init_nested_L7
                LDA     g+8
                CMP     #4
                BNE     _init_nested_L7
                LDA     g+10
                BNE     _init_nested_L7
                LDA     g+12
                BEQ     _init_nested_L6
_init_nested_L7
                INC     _fcc_img0
_init_nested_L6
                LDA     g+15
                AND     #$00FF
                CMP     #98
                BNE     _init_nested_L9
                LDA     g+16
                AND     #$00FF
                BNE     _init_nested_L9
                LDA     g+20
                AND     #$00FF
                CMP     #101
                BNE     _init_nested_L9
                LDA     g+21
                AND     #$00FF
                BEQ     _init_nested_L8
_init_nested_L9
                INC     _fcc_img0
_init_nested_L8
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                INC
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #5
                BNE     _init_nested_L11
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
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
                CMP     #6
                BNE     _init_nested_L11
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #8
                BNE     _init_nested_L11
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                INC
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _init_nested_L10
_init_nested_L11
                INC     _fcc_img0
_init_nested_L10
                LDA     _fcc_img0
                BEQ     _init_nested_L12
                LDA     _fcc_img0
                BRA     _init_nested_L13
_init_nested_L12
                LDA     #42
_init_nested_L13
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
