                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pwdops.c
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _pwdops_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _pwdops_L1
                LDA     #0
                BRL     _pwdops_L2
_pwdops_L1
                LDA     #1
_pwdops_L2
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _pwdops_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _pwdops_L6
                LDA     #0
                BRL     _pwdops_L7
_pwdops_L6
                LDA     #1
_pwdops_L7
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L4
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _pwdops_L4
                LDA     #1
                BRL     _pwdops_L5
_pwdops_L4
                LDA     #0
_pwdops_L5
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _pwdops_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _pwdops_L11
                LDA     #0
                BRL     _pwdops_L12
_pwdops_L11
                LDA     #1
_pwdops_L12
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L9
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
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                LDY     #24
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #26
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _pwdops_L9
                LDA     #1
                BRL     _pwdops_L10
_pwdops_L9
                LDA     #0
_pwdops_L10
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L8
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L8
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _pwdops_L16
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _pwdops_L16
                LDA     #0
                BRL     _pwdops_L17
_pwdops_L16
                LDA     #1
_pwdops_L17
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L14
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
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                LDY     #28
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #30
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _pwdops_L14
                LDA     #1
                BRL     _pwdops_L15
_pwdops_L14
                LDA     #0
_pwdops_L15
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L13
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L13
                LDA     #0
                PHA
                FGX2_FARCALL getpwuid
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _pwdops_L21
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _pwdops_L21
                LDA     #0
                BRL     _pwdops_L22
_pwdops_L21
                LDA     #1
_pwdops_L22
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L19
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
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _pwdops_L19
                LDA     #1
                BRL     _pwdops_L20
_pwdops_L19
                LDA     #0
_pwdops_L20
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L18
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L18
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
                BEQ     *+5
                BRL     _pwdops_L24
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _pwdops_L24
                LDA     #1
                BRL     _pwdops_L25
_pwdops_L24
                LDA     #0
_pwdops_L25
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L23
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L23
                FGX2_FARCALL setpwent
_pwdops_L26
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                FGX2_FARCALL getpwent
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _pwdops_L28
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _pwdops_L28
                LDA     #0
                BRL     _pwdops_L29
_pwdops_L28
                LDA     #1
_pwdops_L29
                CMP     #0
                BNE     *+5
                BRL     _pwdops_L27
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #1
                STA     7,S   ; fccstk d=0 b=7
                BRL     _pwdops_L26
_pwdops_L27
                FGX2_FARCALL endpwent
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _pwdops_L30
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_pwdops_L30
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 11
