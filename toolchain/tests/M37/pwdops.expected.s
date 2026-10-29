                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pwdops.c
;---------------------------------------

                MX      %00
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
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pwdops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getpwnam
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _pwdops_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _pwdops_L1
                LDA     #0
                BRA     _pwdops_L2
_pwdops_L1
                LDA     #1
_pwdops_L2
                CMP     #0
                BEQ     _pwdops_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _pwdops_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _pwdops_L4
                LDA     #0
                BRA     _pwdops_L5
_pwdops_L4
                LDA     #1
_pwdops_L5
                CMP     #0
                BEQ     _pwdops_L3
                LDY     #8
                LDA     [_fcc_img16],Y
                BNE     _pwdops_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L3
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _pwdops_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _pwdops_L7
                LDA     #0
                BRA     _pwdops_L8
_pwdops_L7
                LDA     #1
_pwdops_L8
                CMP     #0
                BEQ     _pwdops_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pwdops_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
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
                BNE     _pwdops_L6
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L6
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _pwdops_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _pwdops_L10
                LDA     #0
                BRA     _pwdops_L11
_pwdops_L10
                LDA     #1
_pwdops_L11
                CMP     #0
                BEQ     _pwdops_L9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pwdops_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDY     #28
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
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
                BNE     _pwdops_L9
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L9
                LDA     #0
                PHA
                FGX2_FARCALL getpwuid
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _pwdops_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _pwdops_L13
                LDA     #0
                BRA     _pwdops_L14
_pwdops_L13
                LDA     #1
_pwdops_L14
                CMP     #0
                BEQ     _pwdops_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pwdops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     [_fcc_img16]
                PHA
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
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
                BNE     _pwdops_L12
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pwdops_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getpwnam
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _pwdops_L16
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _pwdops_L16
                LDA     #1
                BRA     _pwdops_L17
_pwdops_L16
                LDA     #0
_pwdops_L17
                CMP     #0
                BEQ     _pwdops_L15
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L15
                FGX2_FARCALL setpwent
_pwdops_L18
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                FGX2_FARCALL getpwent
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _pwdops_L20
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _pwdops_L20
                LDA     #0
                BRA     _pwdops_L21
_pwdops_L20
                LDA     #1
_pwdops_L21
                CMP     #0
                BEQ     _pwdops_L19
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #1
                STA     7,S   ; fccstk d=0 b=7
                BRA     _pwdops_L18
_pwdops_L19
                FGX2_FARCALL endpwent
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CMP     #1
                BNE     _pwdops_L22
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L22
                LDA     5,S   ; fccstk d=0 b=5
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 11
