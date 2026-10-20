                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sigsdef.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT mode2octal
mode2octal            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mode2octal_FRAMESIZE
                DO      mode2octal_STKGUARD
                BCC     mode2octal_stkovf
                CMP     _fcc_stkfloor
                BCS     mode2octal_stkok
mode2octal_stkovf       JMP     _fcc_stkoflow
                FIN
mode2octal_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #mode2octal_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mode2octal_FRAMESIZE   EQU     0
mode2octal_STKGUARD    EQU     0
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
                LDA     #msbuf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #msbuf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #98
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #msbuf
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                FGX2_FARCALL mode2octal
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #msbuf
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #0
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #-2
_sigsdef_L0
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _sigsdef_L0
                FGX2_FARCALL strlen
                TAY
                TSC
                CLC
                ADC     #0
                TCS
                TYA
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
                FGX2_RELOC_COUNT 5
