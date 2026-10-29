                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from freadn.c
;---------------------------------------

                MX      %00
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
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     _fcc_img18
_freadn_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                TAX
                SEC
                SBC     #36
                BVC     _freadn_L3
                EOR     #$8000
_freadn_L3
                BPL     _freadn_L2
                LDA     #rec
                PHA
                LDA     _fcc_img18
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                CLC
                ADC     _fcc_img18
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
_freadn_L1
                INC     _fcc_img18
                BRA     _freadn_L0
_freadn_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_freadn_S1
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
                LDA     #_freadn_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fopen
                TAY
                TSC
                CLC
                ADC     #8
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
                BNE     _freadn_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _freadn_L5
                LDA     #0
                BRA     _freadn_L6
_freadn_L5
                LDA     #1
_freadn_L6
                CMP     #0
                BEQ     _freadn_L4
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #3
                PHA
                LDA     #12
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rec
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fwrite
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                TAX
                CMP     #3
                BNE     _freadn_L4
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_freadn_L4
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_freadn_S2
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
                LDA     #_freadn_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fopen
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #2
                PHA
                LDA     #12
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #in
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     7,S   ; fccstk d=0 b=7
                TAX
                CMP     #2
                BNE     _freadn_L7
                LDA     #0
                TAX
                LDA:    in,X
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _freadn_L7
                LDA     #23
                TAX
                LDA:    in,X
                AND     #$00FF
                PHA
                LDA     #97
                TAX
                CLC
                ADC     #23
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _freadn_L7
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_freadn_L7
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #2
                PHA
                LDA     #12
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #in
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     7,S   ; fccstk d=0 b=7
                TAX
                CMP     #1
                BNE     _freadn_L8
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_freadn_L8
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #1
                PHA
                LDA     #12
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #in
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     7,S   ; fccstk d=0 b=7
                BNE     _freadn_L9
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #4
                STA     5,S   ; fccstk d=0 b=5
_freadn_L9
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_freadn_S2
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
                LDA     #_freadn_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fopen
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #36
                PHA
                LDA     #1
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #in
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     7,S   ; fccstk d=0 b=7
                TAX
                CMP     #36
                BNE     _freadn_L10
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_freadn_L10
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_freadn_S2
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
                LDA     #_freadn_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fopen
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fgetc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #2
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
                LDA     #in
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fread
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     7,S   ; fccstk d=0 b=7
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #97
                BNE     _freadn_L11
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CMP     #2
                BNE     _freadn_L11
                LDA     #0
                TAX
                LDA:    in,X
                AND     #$00FF
                TAX
                CMP     #98
                BNE     _freadn_L11
                LDA     #7
                TAX
                LDA:    in,X
                AND     #$00FF
                PHA
                LDA     #97
                TAX
                CLC
                ADC     #8
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _freadn_L11
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_freadn_L11
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL fclose
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_freadn_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
                LDA     5,S   ; fccstk d=0 b=5
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
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 18
