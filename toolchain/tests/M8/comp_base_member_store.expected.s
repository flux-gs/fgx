                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from comp_base_member_store.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT lookup
lookup            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #lookup_FRAMESIZE
                DO      lookup_STKGUARD
                BCC     lookup_stkovf
                CMP     _fcc_stkfloor
                BCS     lookup_stkok
lookup_stkovf       JMP     _fcc_stkoflow
                FIN
lookup_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+lookup_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+lookup_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+lookup_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #nodes
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #lookup_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
lookup_FRAMESIZE   EQU     0
lookup_STKGUARD    EQU     0
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
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #nodes
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #8
                LDY     #12
                STA     [_fcc_fpr0],Y
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                ORA     #32
                STA     [_fcc_fpr0]
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                INC
                INC
                STA     [_fcc_fpr0]
                LDA     #1
                PHA
                FGX2_FARCALL lookup
                TAY
                PLA
                TYA
                LDY     #12
                LDA     [_fcc_fpr0],Y
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
                FGX2_RELOC_COUNT 6
