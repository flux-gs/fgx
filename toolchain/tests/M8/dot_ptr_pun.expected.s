                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dot_ptr_pun.c
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
                LDA     #node
                STA     p
                LDA     _fcc_fpr0+2
                STA     p+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #p
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #p
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     #42
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     p
                STA     _fcc_fpr0
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
