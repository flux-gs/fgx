                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from knr_pun_charptr.c
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
                STA     args
                LDA     _fcc_fpr0+2
                STA     args+2
                SEP     #$20
                MX      %10
                LDA     args+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     args
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #42
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     args+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     args
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     args+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     args
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
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _knr_pun_charptr_L2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _knr_pun_charptr_L2
                LDA     #1
                BRL     _knr_pun_charptr_L3
_knr_pun_charptr_L2
                LDA     #0
_knr_pun_charptr_L3
                CMP     #0
                BNE     *+5
                BRL     _knr_pun_charptr_L0
                SEP     #$20
                MX      %10
                LDA     args+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     args
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BRL     _knr_pun_charptr_L1
_knr_pun_charptr_L0
                LDA     #0
_knr_pun_charptr_L1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
