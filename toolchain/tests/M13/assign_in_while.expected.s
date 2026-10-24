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
                LDA     #7
                STA     g_n
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
_assign_in_while_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                FGX2_FARCALL feed
                STA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BMI     _assign_in_while_L2
                LDA     3,S   ; fccstk d=0 b=3
                CLC
                ADC     1,S   ; fccstk d=0 b=1
                STA     3,S   ; fccstk d=0 b=3
                BRA     _assign_in_while_L1
_assign_in_while_L2
                LDA     3,S   ; fccstk d=0 b=3
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
