                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from assign_in_while.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT feed
feed            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #feed_FRAMESIZE
                DO      feed_STKGUARD
                BCC     feed_stkovf
                CMP     _fcc_stkfloor
                BCS     feed_stkok
feed_stkovf       JMP     _fcc_stkoflow
                FIN
feed_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     g_n
                TAX
                DEC
                STA     g_n
                BPL     _assign_in_while_L0
                LDA     #0
                TAX
                DEC
                TAY
                TSC
                CLC
                ADC     #feed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_assign_in_while_L0
                LDA     g_n
                TAY
                TSC
                CLC
                ADC     #feed_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
feed_FRAMESIZE   EQU     0
feed_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                STA     g_n
                LDA     #0
                STA     _fcc_img16
_assign_in_while_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                FGX2_FARCALL feed
                STA     _fcc_img17
                CMP     #0
                BMI     _assign_in_while_L2
                LDA     _fcc_img16
                CLC
                ADC     _fcc_img17
                STA     _fcc_img16
                BRA     _assign_in_while_L1
_assign_in_while_L2
                LDA     _fcc_img16
                CLC
                ADC     _fcc_img16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
