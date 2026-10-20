                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ws_formfeed.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT a
a            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a_FRAMESIZE
                DO      a_STKGUARD
                BCC     a_stkovf
                CMP     _fcc_stkfloor
                BCS     a_stkok
a_stkovf       JMP     _fcc_stkoflow
                FIN
a_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #40
                TAY
                TSC
                CLC
                ADC     #a_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a_FRAMESIZE   EQU     0
a_STKGUARD    EQU     0
                FGX2_EXPORT b
b            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #b_FRAMESIZE
                DO      b_STKGUARD
                BCC     b_stkovf
                CMP     _fcc_stkfloor
                BCS     b_stkok
b_stkovf       JMP     _fcc_stkoflow
                FIN
b_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #b_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
b_FRAMESIZE   EQU     0
b_STKGUARD    EQU     0
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
                FGX2_FARCALL a
                PHA
                FGX2_FARCALL b
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
                FGX2_RELOC_COUNT 6
