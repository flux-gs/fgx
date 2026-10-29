                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from statmulti.c
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
                STA     main_sl_b
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #main_sl_buf
                STA     main_sl_p
                LDA     _fcc_fpr0+2
                STA     main_sl_p+2
                SEP     #$20
                MX      %10
                LDA     main_sl_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     main_sl_p
                STA     _fcc_fpr0
                LDA     #7
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     main_sl_n+2
                STA     _fcc_long_hi
                LDA     main_sl_n
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #100
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
                BNE     *+5
                BRL     _statmulti_L0
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
_statmulti_L0
                SEP     #$20
                MX      %10
                LDA     main_sl_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     main_sl_p
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #7
                BNE     *+5
                BRL     _statmulti_L1
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
_statmulti_L1
                LDA     main_sl_a
                CLC
                ADC     main_sl_b
                CLC
                ADC     main_sl_c
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
