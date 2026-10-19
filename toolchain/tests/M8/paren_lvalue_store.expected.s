                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from paren_lvalue_store.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT rhs_val
rhs_val            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #rhs_val_FRAMESIZE
                DO      rhs_val_STKGUARD
                BCC     rhs_val_stkovf
                CMP     _fcc_stkfloor
                BCS     rhs_val_stkok
rhs_val_stkovf       JMP     _fcc_stkoflow
                FIN
rhs_val_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #rhs_val_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
rhs_val_FRAMESIZE   EQU     0
rhs_val_STKGUARD    EQU     0
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
                LDA     #box
                STA     standin
                LDA     _fcc_fpr0+2
                STA     standin+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #standin
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
                FGX2_FARCALL rhs_val
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     [_fcc_fpr0]
                STA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 4
