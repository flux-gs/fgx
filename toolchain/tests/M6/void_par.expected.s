                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from void_par.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT seven
seven            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #seven_FRAMESIZE
                DO      seven_STKGUARD
                BCC     seven_stkovf
                CMP     _fcc_stkfloor
                BCS     seven_stkok
seven_stkovf       JMP     _fcc_stkoflow
                FIN
seven_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #seven_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
seven_FRAMESIZE   EQU     0
seven_STKGUARD    EQU     0
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
                FGX2_FARCALL seven
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
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
                FGX2_RELOC_COUNT 4
