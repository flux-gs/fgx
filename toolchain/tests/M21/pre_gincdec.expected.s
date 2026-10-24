                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pre_gincdec.c
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
                LDA     #40
                STA     gi
                INC
                STA     gi
                INC
                STA     gi
                LDA     #65
                SEP     #$20
                MX      %10
                STA     gc
                REP     #$20
                MX      %00
                LDA     gc
                AND     #$00FF
                SEC
                SBC     #1
                SEP     #$20
                MX      %10
                STA     gc
                REP     #$20
                MX      %00
                LDA     #100
                JSR     _fcc_long_from_int
                STA     gl
                TAY
                LDA     _fcc_long_hi
                STA     gl+2
                TYA
                LDA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                CLC
                ADC     #1
                STA     gl
                LDA     _fcc_long_hi
                ADC     #0
                STA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                SEC
                SBC     #1
                STA     gl
                LDA     _fcc_long_hi
                SBC     #0
                STA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                SEC
                SBC     #1
                STA     gl
                LDA     _fcc_long_hi
                SBC     #0
                STA     gl+2
                LDA     gc
                AND     #$00FF
                TAX
                TXA
                CMP     #64
                BEQ     _pre_gincdec_L0
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
_pre_gincdec_L0
                LDA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #99
                JSR     _fcc_long_from_int
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
                BEQ     _pre_gincdec_L1
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
_pre_gincdec_L1
                LDA     gi
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
