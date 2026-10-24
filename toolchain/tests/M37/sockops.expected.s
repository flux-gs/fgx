                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sockops.c
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
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                PHA
                LDA     #2
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL socket
                TAY
                PLA
                PLA
                PLA
                TYA
                STA     1,S   ; fccstk d=0 b=1
                BMI     _sockops_L0
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #5
                STA     3,S   ; fccstk d=0 b=3
_sockops_L0
                LDA     #16
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sa
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #99
                PHA
                FGX2_FARCALL bind
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L1
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #5
                STA     3,S   ; fccstk d=0 b=3
_sockops_L1
                LDA     #16
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sa
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #99
                PHA
                FGX2_FARCALL connect
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L2
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #5
                STA     3,S   ; fccstk d=0 b=3
_sockops_L2
                LDA     #0
                PHA
                LDA     #4
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #99
                PHA
                FGX2_FARCALL send
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L3
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #5
                STA     3,S   ; fccstk d=0 b=3
_sockops_L3
                LDA     #0
                PHA
                LDA     #8
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #99
                PHA
                FGX2_FARCALL recv
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L4
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #5
                STA     3,S   ; fccstk d=0 b=3
_sockops_L4
                LDA     #4
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                LDA     #0
                PHA
                LDA     #99
                PHA
                FGX2_FARCALL setsockopt
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L5
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #5
                STA     3,S   ; fccstk d=0 b=3
_sockops_L5
                LDA     #16
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sa
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                LDA     #4
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #99
                PHA
                FGX2_FARCALL sendto
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L6
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #4
                STA     3,S   ; fccstk d=0 b=3
_sockops_L6
                LDA     #16
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sa
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                LDA     #8
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #99
                PHA
                FGX2_FARCALL recvfrom
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L7
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #4
                STA     3,S   ; fccstk d=0 b=3
_sockops_L7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sa
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                FGX2_FARCALL ifctl
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #$FFFF
                BNE     _sockops_L8
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #4
                STA     3,S   ; fccstk d=0 b=3
_sockops_L8
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     3,S   ; fccstk d=0 b=3
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
                FGX2_RELOC_COUNT 12
