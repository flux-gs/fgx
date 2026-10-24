                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from strblob.c
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
_strblob_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA:    _strblob_big,X
                AND     #$00FF
                CMP     #0
                BEQ     _strblob_L1
                INC     _fcc_img0
                BRA     _strblob_L0
_strblob_L1
                LDA     _fcc_img0
                TAX
                CMP     #2109
                BEQ     _strblob_L2
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
_strblob_L2
                LDA     #0
                TAX
                LDA:    _strblob_big,X
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _strblob_L4
                LDA     #61
                TAX
                LDA:    _strblob_big,X
                AND     #$00FF
                TAX
                CMP     #65
                BEQ     _strblob_L3
_strblob_L4
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
_strblob_L3
                LDA     #62
                TAX
                LDA:    _strblob_big,X
                AND     #$00FF
                TAX
                CMP     #66
                BEQ     _strblob_L5
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
_strblob_L5
                LDA     #2108
                TAX
                LDA:    _strblob_big,X
                AND     #$00FF
                TAX
                CMP     #64
                BEQ     _strblob_L6
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
_strblob_L6
                LDA     #2109
                TAX
                LDA:    _strblob_big,X
                AND     #$00FF
                BEQ     _strblob_L7
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
_strblob_L7
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
