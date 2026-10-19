                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sigdbr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sig_handler
sig_handler            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sig_handler_FRAMESIZE
                DO      sig_handler_STKGUARD
                BCC     sig_handler_stkovf
                CMP     _fcc_stkfloor
                BCS     sig_handler_stkok
sig_handler_stkovf       JMP     _fcc_stkoflow
                FIN
sig_handler_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #16896
                TAX
                DO      6+sig_handler_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sig_handler_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sig_handler_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     sig_flag
                TAY
                TSC
                CLC
                ADC     #sig_handler_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sig_handler_FRAMESIZE   EQU     0
sig_handler_STKGUARD    EQU     0
                FGX2_EXPORT churn
churn            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #churn_FRAMESIZE
                DO      churn_STKGUARD
                BCC     churn_stkovf
                CMP     _fcc_stkfloor
                BCS     churn_stkok
churn_stkovf       JMP     _fcc_stkoflow
                FIN
churn_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+churn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+churn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+churn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #churn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
churn_FRAMESIZE   EQU     2
churn_STKGUARD    EQU     0
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
                LDA     _sigdbr_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _sigdbr_FA1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                FGX2_FARCALL signal
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                PHA
                LDA     #1
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sigdbr_L0
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
_sigdbr_L0
                LDA     #1
                PHA
                FGX2_FARCALL churn
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL churn
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sigdbr_L2
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
_sigdbr_L2
                LDA     #2
                PHA
                FGX2_FARCALL getpid
                PHA
                FGX2_FARCALL kill
                TAY
                PLA
                PLA
                TYA
                LDA     sig_flag
                TAX
                LDA     #16898
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _sigdbr_L3
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
_sigdbr_L3
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
                FGX2_RELOC_COUNT 9
