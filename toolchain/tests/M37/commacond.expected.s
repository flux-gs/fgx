                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from commacond.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT next
next            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #next_FRAMESIZE
                DO      next_STKGUARD
                BCC     next_stkovf
                CMP     _fcc_stkfloor
                BCS     next_stkok
next_stkovf       JMP     _fcc_stkoflow
                FIN
next_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     fed
                STA     _fcc_tmp_b
                INC
                STA     fed
                LDA     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #next_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
next_FRAMESIZE   EQU     0
next_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                TSC
                SEC
                SBC     #main_FRAMESIZE-6
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img17
                LDA     #3
                STA     fed
_commacond_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                FGX2_FARCALL next
                STA     _fcc_img18
                TAX
                LDA     #6
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BEQ     _commacond_L1
                LDA     _fcc_img17
                CLC
                ADC     _fcc_img18
                STA     _fcc_img17
                BRA     _commacond_L0
_commacond_L1
                LDA     _fcc_img18
                CLC
                ADC     #1
                STA     _fcc_img18
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BEQ     _commacond_L2
                LDA     _fcc_img17
                TAX
                CLC
                ADC     #10
                STA     _fcc_img17
_commacond_L2
                LDA     #0
                STA     _fcc_img16
_commacond_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                CLC
                ADC     #100
                STA     _fcc_img18
                LDA     _fcc_img16
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BEQ     _commacond_L5
                LDA     _fcc_img17
                TAX
                CLC
                ADC     #1
                STA     _fcc_img17
_commacond_L4
                LDA     _fcc_img16
                CLC
                ADC     #1
                STA     _fcc_img16
                BRA     _commacond_L3
_commacond_L5
                LDA     _fcc_img18
                TAX
                CMP     #104
                BNE     _commacond_L6
                LDA     _fcc_img17
                TAX
                CLC
                ADC     #16
                STA     _fcc_img17
_commacond_L6
                LDA     _fcc_img17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-6
                TCS
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
