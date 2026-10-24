                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libso_lit.c
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_lit
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #65
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHK
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libso_lit_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strlen
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_lit
                CLC
                ADC     #0
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strlen
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_lit
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #8
                TAX
                TXA
                CLC
                ADC     #7
                TAX
                TXA
                CLC
                ADC     #65
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _libso_lit_L0
                LDA     #42
                BRA     _libso_lit_L1
_libso_lit_L0
                LDA     #1
_libso_lit_L1
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

;-------------------------------
; M7 string literal pool
;-------------------------------
                FGX2_EXPORT _libso_lit_S0
_libso_lit_S0             HEX     6C,69,74,2D,70,74,72,00
                FGX2_EXPORT _libso_lit_S1
_libso_lit_S1             HEX     65,78,70,72,2D,6C,69,74,00
                FGX2_RELOC_COUNT 6
