                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m11_libc_test.c
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_m11_libc_test_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strlen
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_m11_libc_test_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_m11_libc_test_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strcmp
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_m11_libc_test_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL printf
                TSC
                CLC
                ADC     #8
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
