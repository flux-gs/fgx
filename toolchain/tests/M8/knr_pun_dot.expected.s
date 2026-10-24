                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from knr_pun_dot.c
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
                LDA     #42
                STA     storage+4
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #storage
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     np
                LDA     _fcc_fpr0+2
                STA     np+2
                LDA     np
                STA     _fcc_img0
                LDA     np
                TAX
                TXA
                EOR     #1
                STA     np
                SEP     #$20
                MX      %10
                LDA     np+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     np
                STA     _fcc_fpr0
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_ne16
                STA     3,S   ; fccstk d=0 b=3
                LDA     np
                TAX
                TXA
                EOR     #1
                STA     np
                SEP     #$20
                MX      %10
                LDA     np+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     np
                STA     _fcc_fpr0
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                STA     5,S   ; fccstk d=0 b=5
                LDA     np
                TAX
                TXA
                ORA     #1
                STA     np
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     np
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #storage
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     np
                LDA     _fcc_fpr0+2
                STA     np+2
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #0
                BEQ     _knr_pun_dot_L2
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BEQ     _knr_pun_dot_L2
                LDA     #1
                BRA     _knr_pun_dot_L3
_knr_pun_dot_L2
                LDA     #0
_knr_pun_dot_L3
                CMP     #0
                BEQ     _knr_pun_dot_L0
                SEP     #$20
                MX      %10
                LDA     np+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     np
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                BRA     _knr_pun_dot_L1
_knr_pun_dot_L0
                LDA     #0
_knr_pun_dot_L1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
