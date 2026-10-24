                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pfsign.c
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
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$FFD6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfsign_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #32
                BEQ     *+5
                BRL     _pfsign_L11
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #32
                BEQ     *+5
                BRL     _pfsign_L11
                LDA     #1
                BRL     _pfsign_L12
_pfsign_L11
                LDA     #0
_pfsign_L12
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L9
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #32
                BEQ     *+5
                BRL     _pfsign_L9
                LDA     #1
                BRL     _pfsign_L10
_pfsign_L9
                LDA     #0
_pfsign_L10
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L7
                LDA     #3
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #45
                BEQ     *+5
                BRL     _pfsign_L7
                LDA     #1
                BRL     _pfsign_L8
_pfsign_L7
                LDA     #0
_pfsign_L8
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L5
                LDA     #4
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #52
                BEQ     *+5
                BRL     _pfsign_L5
                LDA     #1
                BRL     _pfsign_L6
_pfsign_L5
                LDA     #0
_pfsign_L6
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L3
                LDA     #5
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #50
                BEQ     *+5
                BRL     _pfsign_L3
                LDA     #1
                BRL     _pfsign_L4
_pfsign_L3
                LDA     #0
_pfsign_L4
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L1
                LDA     #6
                TAX
                LDA:    buf,X
                AND     #$00FF
                CMP     #0
                BEQ     *+5
                BRL     _pfsign_L1
                LDA     #1
                BRL     _pfsign_L2
_pfsign_L1
                LDA     #0
_pfsign_L2
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #20
                STA     1,S   ; fccstk d=0 b=1
_pfsign_L0
                LDA     #$FFD6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfsign_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #45
                BEQ     *+5
                BRL     _pfsign_L22
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #48
                BEQ     *+5
                BRL     _pfsign_L22
                LDA     #1
                BRL     _pfsign_L23
_pfsign_L22
                LDA     #0
_pfsign_L23
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L20
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #48
                BEQ     *+5
                BRL     _pfsign_L20
                LDA     #1
                BRL     _pfsign_L21
_pfsign_L20
                LDA     #0
_pfsign_L21
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L18
                LDA     #3
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #48
                BEQ     *+5
                BRL     _pfsign_L18
                LDA     #1
                BRL     _pfsign_L19
_pfsign_L18
                LDA     #0
_pfsign_L19
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L16
                LDA     #4
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #52
                BEQ     *+5
                BRL     _pfsign_L16
                LDA     #1
                BRL     _pfsign_L17
_pfsign_L16
                LDA     #0
_pfsign_L17
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L14
                LDA     #5
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #50
                BEQ     *+5
                BRL     _pfsign_L14
                LDA     #1
                BRL     _pfsign_L15
_pfsign_L14
                LDA     #0
_pfsign_L15
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L13
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_pfsign_L13
                LDA     #$FFD6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfsign_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #45
                BEQ     *+5
                BRL     _pfsign_L33
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #52
                BEQ     *+5
                BRL     _pfsign_L33
                LDA     #1
                BRL     _pfsign_L34
_pfsign_L33
                LDA     #0
_pfsign_L34
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L31
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #50
                BEQ     *+5
                BRL     _pfsign_L31
                LDA     #1
                BRL     _pfsign_L32
_pfsign_L31
                LDA     #0
_pfsign_L32
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L29
                LDA     #3
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #32
                BEQ     *+5
                BRL     _pfsign_L29
                LDA     #1
                BRL     _pfsign_L30
_pfsign_L29
                LDA     #0
_pfsign_L30
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L27
                LDA     #5
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #32
                BEQ     *+5
                BRL     _pfsign_L27
                LDA     #1
                BRL     _pfsign_L28
_pfsign_L27
                LDA     #0
_pfsign_L28
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L25
                LDA     #6
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #88
                BEQ     *+5
                BRL     _pfsign_L25
                LDA     #1
                BRL     _pfsign_L26
_pfsign_L25
                LDA     #0
_pfsign_L26
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L24
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_pfsign_L24
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pfsign_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #12
                TCS
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #32
                BEQ     *+5
                BRL     _pfsign_L40
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #32
                BEQ     *+5
                BRL     _pfsign_L40
                LDA     #1
                BRL     _pfsign_L41
_pfsign_L40
                LDA     #0
_pfsign_L41
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L38
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #45
                BEQ     *+5
                BRL     _pfsign_L38
                LDA     #1
                BRL     _pfsign_L39
_pfsign_L38
                LDA     #0
_pfsign_L39
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L36
                LDA     #3
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #55
                BEQ     *+5
                BRL     _pfsign_L36
                LDA     #1
                BRL     _pfsign_L37
_pfsign_L36
                LDA     #0
_pfsign_L37
                CMP     #0
                BNE     *+5
                BRL     _pfsign_L35
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_pfsign_L35
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
