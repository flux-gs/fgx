                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sfld_subscript.c
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
                LDA     r+2
                STA     _fcc_fpr0+2
                LDA     r+0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #99
                BEQ     _sfld_subscript_L0
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
_sfld_subscript_L0
                LDA     r+6
                STA     _fcc_fpr0+2
                LDA     r+4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     r+2
                STA     _fcc_fpr0+2
                LDA     r+0
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #g+2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
