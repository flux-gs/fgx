                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from decl_list_fn.c
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
                LDA     #30
                STA     timedout
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     y
                TAY
                LDA     _fcc_long_hi
                STA     y+2
                TYA
                FGX2_FARCALL timeout
                PHA
                FGX2_FARCALL g
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$8696
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
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
                FGX2_EXPORT timeout
timeout            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #timeout_FRAMESIZE
                DO      timeout_STKGUARD
                BCC     timeout_stkovf
                CMP     _fcc_stkfloor
                BCS     timeout_stkok
timeout_stkovf       JMP     _fcc_stkoflow
                FIN
timeout_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     timedout
                TAY
                TSC
                CLC
                ADC     #timeout_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
timeout_FRAMESIZE   EQU     0
timeout_STKGUARD    EQU     0
                FGX2_EXPORT g
g            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #g_FRAMESIZE
                DO      g_STKGUARD
                BCC     g_stkovf
                CMP     _fcc_stkfloor
                BCS     g_stkok
g_stkovf       JMP     _fcc_stkoflow
                FIN
g_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     y+2
                STA     _fcc_long_hi
                LDA     y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                TSC
                CLC
                ADC     #g_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
g_FRAMESIZE   EQU     0
g_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
