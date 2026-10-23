                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sl_counter.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT next_id
next_id            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #next_id_FRAMESIZE
                DO      next_id_STKGUARD
                BCC     next_id_stkovf
                CMP     _fcc_stkfloor
                BCS     next_id_stkok
next_id_stkovf       JMP     _fcc_stkoflow
                FIN
next_id_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     next_id_sl_c
                TAX
                TXA
                INC
                STA     next_id_sl_c
                TAY
                TSC
                CLC
                ADC     #next_id_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
next_id_FRAMESIZE   EQU     0
next_id_STKGUARD    EQU     0
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
                FGX2_FARCALL next_id
                FGX2_FARCALL next_id
                FGX2_FARCALL next_id
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
