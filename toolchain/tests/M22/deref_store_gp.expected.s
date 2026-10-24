                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from deref_store_gp.c
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
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                INC
                STA     gp
                LDA     #65
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                STA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #65
                BEQ     _deref_store_gp_L0
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
_deref_store_gp_L0
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #65
                BEQ     _deref_store_gp_L1
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
_deref_store_gp_L1
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #buf
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _deref_store_gp_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _deref_store_gp_L3
                LDA     #0
                BRA     _deref_store_gp_L4
_deref_store_gp_L3
                LDA     #1
_deref_store_gp_L4
                CMP     #0
                BEQ     _deref_store_gp_L2
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
_deref_store_gp_L2
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                INC
                STA     gp
                LDA     #66
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                TAX
                CMP     #66
                BEQ     _deref_store_gp_L5
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
_deref_store_gp_L5
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #66
                BEQ     _deref_store_gp_L6
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
_deref_store_gp_L6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ibuf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     ip
                LDA     _fcc_fpr0+2
                STA     ip+2
                SEP     #$20
                MX      %10
                LDA     ip+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ip
                STA     _fcc_fpr0
                INC
                INC
                STA     ip
                LDA     #1000
                STA     [_fcc_fpr0]
                TAX
                CMP     #1000
                BEQ     _deref_store_gp_L7
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
_deref_store_gp_L7
                LDA     #0
                ASL
                TAX
                LDA:    ibuf,X
                TAX
                CMP     #1000
                BEQ     _deref_store_gp_L8
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
_deref_store_gp_L8
                SEP     #$20
                MX      %10
                LDA     ip+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     ip
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     #ibuf
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _deref_store_gp_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _deref_store_gp_L10
                LDA     #0
                BRA     _deref_store_gp_L11
_deref_store_gp_L10
                LDA     #1
_deref_store_gp_L11
                CMP     #0
                BEQ     _deref_store_gp_L9
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_deref_store_gp_L9
                LDA     #42
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
