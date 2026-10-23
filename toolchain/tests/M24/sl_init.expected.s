                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sl_init.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT seq
seq            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #seq_FRAMESIZE
                DO      seq_STKGUARD
                BCC     seq_stkovf
                CMP     _fcc_stkfloor
                BCS     seq_stkok
seq_stkovf       JMP     _fcc_stkoflow
                FIN
seq_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     seq_sl_n
                TAX
                TXA
                INC
                STA     seq_sl_n
                TAY
                TSC
                CLC
                ADC     #seq_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
seq_FRAMESIZE   EQU     0
seq_STKGUARD    EQU     0
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
                FGX2_FARCALL seq
                FGX2_FARCALL seq
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
                FGX2_RELOC_COUNT 5
