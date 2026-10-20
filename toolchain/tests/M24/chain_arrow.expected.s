                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from chain_arrow.c
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
                LDA     #s1
                STA     sp
                LDA     _fcc_fpr0+2
                STA     sp+2
                SEP     #$20
                MX      %10
                LDA     sp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     sp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     sp+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     sp
                STA     _fcc_fpr1
                LDA     #9
                LDY     #2
                STA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     sp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     sp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDA     sp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     sp
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
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
