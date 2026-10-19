                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from charincdec.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT clear
clear            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #clear_FRAMESIZE
                DO      clear_STKGUARD
                BCC     clear_stkovf
                CMP     _fcc_stkfloor
                BCS     clear_stkok
clear_stkovf       JMP     _fcc_stkoflow
                FIN
clear_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #65
                SEP     #$20
                MX      %10
                STA     gs+0
                REP     #$20
                MX      %00
                LDA     #4
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                LDA     #67
                SEP     #$20
                MX      %10
                STA     gs+2
                REP     #$20
                MX      %00
                LDA     #81
                SEP     #$20
                MX      %10
                STA     gq+0
                REP     #$20
                MX      %00
                LDA     #4
                SEP     #$20
                MX      %10
                STA     gq+1
                REP     #$20
                MX      %00
                LDA     #83
                SEP     #$20
                MX      %10
                STA     gq+2
                REP     #$20
                MX      %00
                LDA     #84
                SEP     #$20
                MX      %10
                STA     gq+4
                REP     #$20
                MX      %00
                LDA     #24930
                STA     go+0
                LDA     #4
                SEP     #$20
                MX      %10
                STA     go+2
                REP     #$20
                MX      %00
                LDA     #99
                SEP     #$20
                MX      %10
                STA     go+4
                REP     #$20
                MX      %00
                LDA     #carr
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #113
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
                LDA     #carr
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #4
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
                LDA     #carr
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #115
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
                LDA     #carr
                PHA
                LDA     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #116
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
                LDA     #4
                SEP     #$20
                MX      %10
                STA     gu
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #clear_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
clear_FRAMESIZE   EQU     0
clear_STKGUARD    EQU     0
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
                STA     9,S   ; fccstk d=0 b=9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gq
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                FGX2_FARCALL clear
                LDA     #0
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L0
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
_charincdec_L0
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L6
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L6
                LDA     #1
                BRL     _charincdec_L7
_charincdec_L6
                LDA     #0
_charincdec_L7
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L4
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L4
                LDA     #1
                BRL     _charincdec_L5
_charincdec_L4
                LDA     #0
_charincdec_L5
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L2
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L2
                LDA     #1
                BRL     _charincdec_L3
_charincdec_L2
                LDA     #0
_charincdec_L3
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L1
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L1
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L13
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L13
                LDA     #1
                BRL     _charincdec_L14
_charincdec_L13
                LDA     #0
_charincdec_L14
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L11
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L11
                LDA     #1
                BRL     _charincdec_L12
_charincdec_L11
                LDA     #0
_charincdec_L12
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L9
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L9
                LDA     #1
                BRL     _charincdec_L10
_charincdec_L9
                LDA     #0
_charincdec_L10
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L8
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L8
                FGX2_FARCALL clear
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L20
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L20
                LDA     #1
                BRL     _charincdec_L21
_charincdec_L20
                LDA     #0
_charincdec_L21
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L18
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L18
                LDA     #1
                BRL     _charincdec_L19
_charincdec_L18
                LDA     #0
_charincdec_L19
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L16
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L16
                LDA     #1
                BRL     _charincdec_L17
_charincdec_L16
                LDA     #0
_charincdec_L17
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L15
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L15
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L27
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L27
                LDA     #1
                BRL     _charincdec_L28
_charincdec_L27
                LDA     #0
_charincdec_L28
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L25
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L25
                LDA     #1
                BRL     _charincdec_L26
_charincdec_L25
                LDA     #0
_charincdec_L26
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L23
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L23
                LDA     #1
                BRL     _charincdec_L24
_charincdec_L23
                LDA     #0
_charincdec_L24
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L22
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L22
                FGX2_FARCALL clear
                LDA     #1
                STA     13,S   ; fccstk d=0 b=13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #carr
                STA     _fcc_fpr0
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L36
                LDA     #1
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L36
                LDA     #1
                BRL     _charincdec_L37
_charincdec_L36
                LDA     #0
_charincdec_L37
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L34
                LDA     #0
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                LDA     #113
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L34
                LDA     #1
                BRL     _charincdec_L35
_charincdec_L34
                LDA     #0
_charincdec_L35
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L32
                LDA     #2
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                LDA     #115
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L32
                LDA     #1
                BRL     _charincdec_L33
_charincdec_L32
                LDA     #0
_charincdec_L33
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L30
                LDA     #3
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                LDA     #116
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L30
                LDA     #1
                BRL     _charincdec_L31
_charincdec_L30
                LDA     #0
_charincdec_L31
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L29
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L29
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
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
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L45
                LDA     gq+1
                AND     #$00FF
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L45
                LDA     #1
                BRL     _charincdec_L46
_charincdec_L45
                LDA     #0
_charincdec_L46
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L43
                LDA     gq+0
                AND     #$00FF
                TAX
                LDA     #81
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L43
                LDA     #1
                BRL     _charincdec_L44
_charincdec_L43
                LDA     #0
_charincdec_L44
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L41
                LDA     gq+2
                AND     #$00FF
                TAX
                LDA     #83
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L41
                LDA     #1
                BRL     _charincdec_L42
_charincdec_L41
                LDA     #0
_charincdec_L42
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L39
                LDA     gq+4
                AND     #$00FF
                TAX
                LDA     #84
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L39
                LDA     #1
                BRL     _charincdec_L40
_charincdec_L39
                LDA     #0
_charincdec_L40
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L38
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L38
                FGX2_FARCALL clear
                LDA     #255
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L47
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
_charincdec_L47
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L53
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L53
                LDA     #1
                BRL     _charincdec_L54
_charincdec_L53
                LDA     #0
_charincdec_L54
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L51
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L51
                LDA     #1
                BRL     _charincdec_L52
_charincdec_L51
                LDA     #0
_charincdec_L52
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L49
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L49
                LDA     #1
                BRL     _charincdec_L50
_charincdec_L49
                LDA     #0
_charincdec_L50
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L48
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L48
                FGX2_FARCALL clear
                LDA     #255
                SEP     #$20
                MX      %10
                STA     gs+1
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L60
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L60
                LDA     #1
                BRL     _charincdec_L61
_charincdec_L60
                LDA     #0
_charincdec_L61
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L58
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L58
                LDA     #1
                BRL     _charincdec_L59
_charincdec_L58
                LDA     #0
_charincdec_L59
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L56
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L56
                LDA     #1
                BRL     _charincdec_L57
_charincdec_L56
                LDA     #0
_charincdec_L57
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L55
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L55
                FGX2_FARCALL clear
                LDA     #0
                SEP     #$20
                MX      %10
                STA     gs+1
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L67
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L67
                LDA     #1
                BRL     _charincdec_L68
_charincdec_L67
                LDA     #0
_charincdec_L68
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L65
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L65
                LDA     #1
                BRL     _charincdec_L66
_charincdec_L65
                LDA     #0
_charincdec_L66
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L63
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L63
                LDA     #1
                BRL     _charincdec_L64
_charincdec_L63
                LDA     #0
_charincdec_L64
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L62
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L62
                FGX2_FARCALL clear
                LDA     #0
                SEP     #$20
                MX      %10
                STA     gs+1
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L74
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L74
                LDA     #1
                BRL     _charincdec_L75
_charincdec_L74
                LDA     #0
_charincdec_L75
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L72
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L72
                LDA     #1
                BRL     _charincdec_L73
_charincdec_L72
                LDA     #0
_charincdec_L73
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L70
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L70
                LDA     #1
                BRL     _charincdec_L71
_charincdec_L70
                LDA     #0
_charincdec_L71
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L69
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L69
                FGX2_FARCALL clear
                LDA     #255
                SEP     #$20
                MX      %10
                STA     go+2
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #go
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L81
                LDA     go+2
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L81
                LDA     #1
                BRL     _charincdec_L82
_charincdec_L81
                LDA     #0
_charincdec_L82
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L79
                LDA     go+4
                AND     #$00FF
                TAX
                LDA     #99
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L79
                LDA     #1
                BRL     _charincdec_L80
_charincdec_L79
                LDA     #0
_charincdec_L80
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L77
                LDA     go+0
                TAX
                LDA     #24930
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L77
                LDA     #1
                BRL     _charincdec_L78
_charincdec_L77
                LDA     #0
_charincdec_L78
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L76
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L76
                FGX2_FARCALL clear
                LDA     #255
                SEP     #$20
                MX      %10
                STA     gu
                REP     #$20
                MX      %00
                LDA     gu
                AND     #$00FF
                STA     _fcc_tmp_b
                INC
                SEP     #$20
                MX      %10
                STA     gu
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L84
                LDA     gu
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L84
                LDA     #1
                BRL     _charincdec_L85
_charincdec_L84
                LDA     #0
_charincdec_L85
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L83
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L83
                FGX2_FARCALL clear
                LDA     #255
                SEP     #$20
                MX      %10
                STA     gs+1
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                CLC
                ADC     #1
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                JSR     _fcc_long_from_int
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #255
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L89
                LDA     gs+1
                AND     #$00FF
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L89
                LDA     #1
                BRL     _charincdec_L90
_charincdec_L89
                LDA     #0
_charincdec_L90
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L87
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L87
                LDA     #1
                BRL     _charincdec_L88
_charincdec_L87
                LDA     #0
_charincdec_L88
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L86
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L86
                FGX2_FARCALL clear
                LDA     #16
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                LDA     #32
                SEP     #$20
                MX      %10
                STA     gs+2
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                LDA     #42
                SEP     #$20
                MX      %10
                STA     gs+2
                REP     #$20
                MX      %00
                LDA     11,S   ; fccstk d=0 b=11
                PHA
                LDA     gs+1
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     11,S   ; fccstk d=0 b=11
                PHA
                LDA     #17
                TAX
                LDA     #17
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L94
                LDA     gs+2
                AND     #$00FF
                TAX
                LDA     #42
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L94
                LDA     #1
                BRL     _charincdec_L95
_charincdec_L94
                LDA     #0
_charincdec_L95
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L92
                LDA     gs+0
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _charincdec_L92
                LDA     #1
                BRL     _charincdec_L93
_charincdec_L92
                LDA     #0
_charincdec_L93
                CMP     #0
                BNE     *+5
                BRL     _charincdec_L91
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L91
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 17
