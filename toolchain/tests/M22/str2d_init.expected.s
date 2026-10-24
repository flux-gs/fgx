                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from str2d_init.c
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
                ASL
                ASL
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                TAX
                CMP     #67
                BEQ     _str2d_init_L0
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
_str2d_init_L0
                LDA     #0
                ASL
                ASL
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                TAX
                CMP     #44
                BEQ     _str2d_init_L1
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
_str2d_init_L1
                LDA     #0
                ASL
                ASL
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                TAX
                CMP     #5
                BEQ     _str2d_init_L2
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
_str2d_init_L2
                LDA     #0
                ASL
                ASL
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                BEQ     _str2d_init_L3
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
_str2d_init_L3
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                TAX
                CMP     #97
                BEQ     _str2d_init_L4
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
_str2d_init_L4
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                BEQ     _str2d_init_L5
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
_str2d_init_L5
                LDA     #2
                ASL
                ASL
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                BEQ     _str2d_init_L6
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
_str2d_init_L6
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                PHA
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    dig,X
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     #43
                CLC
                ADC     1,S   ; fccstk d=0 b=1
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
