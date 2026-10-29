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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gq
                STA     _fcc_fpr0
                PLA
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
                BNE     _charincdec_L0
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
_charincdec_L0
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #1
                BNE     _charincdec_L1
                LDA     gs+1
                AND     #$00FF
                TAX
                CMP     #1
                BNE     _charincdec_L1
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L1
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L1
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
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
                CMP     #4
                BNE     _charincdec_L2
                LDA     gs+1
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _charincdec_L2
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L2
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L2
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L2
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
                CMP     #5
                BNE     _charincdec_L3
                LDA     gs+1
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _charincdec_L3
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L3
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L3
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L3
                FGX2_FARCALL clear
                LDA     gs+1
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #5
                BNE     _charincdec_L4
                LDA     gs+1
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _charincdec_L4
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L4
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L4
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L4
                FGX2_FARCALL clear
                LDA     #1
                STA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #carr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #5
                BNE     _charincdec_L5
                LDA     #1
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _charincdec_L5
                LDA     #0
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                CMP     #113
                BNE     _charincdec_L5
                LDA     #2
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                CMP     #115
                BNE     _charincdec_L5
                LDA     #3
                TAX
                LDA:    carr,X
                AND     #$00FF
                TAX
                CMP     #116
                BNE     _charincdec_L5
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L5
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
                LDA     [_fcc_fpr0]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #5
                BNE     _charincdec_L6
                LDA     gq+1
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _charincdec_L6
                LDA     gq+0
                AND     #$00FF
                TAX
                CMP     #81
                BNE     _charincdec_L6
                LDA     gq+2
                AND     #$00FF
                TAX
                CMP     #83
                BNE     _charincdec_L6
                LDA     gq+4
                AND     #$00FF
                TAX
                CMP     #84
                BNE     _charincdec_L6
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L6
                FGX2_FARCALL clear
                LDA     #255
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
                LDA     gs+1
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                AND     #$00FF
                BNE     _charincdec_L7
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
_charincdec_L7
                LDA     11,S   ; fccstk d=0 b=11
                BNE     _charincdec_L8
                LDA     gs+1
                AND     #$00FF
                BNE     _charincdec_L8
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L8
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L8
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L8
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
                CMP     #255
                BNE     _charincdec_L9
                LDA     gs+1
                AND     #$00FF
                BNE     _charincdec_L9
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L9
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L9
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L9
                FGX2_FARCALL clear
                LDA     #0
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                LDA     gs+1
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     gs+1
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     11,S   ; fccstk d=0 b=11
                TAX
                CMP     #255
                BNE     _charincdec_L10
                LDA     gs+1
                AND     #$00FF
                TAX
                CMP     #255
                BNE     _charincdec_L10
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L10
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L10
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L10
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
                BNE     _charincdec_L11
                LDA     gs+1
                AND     #$00FF
                TAX
                CMP     #255
                BNE     _charincdec_L11
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L11
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L11
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L11
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
                CMP     #255
                BNE     _charincdec_L12
                LDA     go+2
                AND     #$00FF
                BNE     _charincdec_L12
                LDA     go+4
                AND     #$00FF
                TAX
                CMP     #99
                BNE     _charincdec_L12
                LDA     go+0
                TAX
                CMP     #24930
                BNE     _charincdec_L12
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L12
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
                CMP     #255
                BNE     _charincdec_L13
                LDA     gu
                AND     #$00FF
                BNE     _charincdec_L13
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L13
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
                LDX     #255
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _charincdec_L14
                LDA     gs+1
                AND     #$00FF
                BNE     _charincdec_L14
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _charincdec_L14
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L14
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
                REP     #$20
                MX      %00
                LDA     gs+1
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     gs+1
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
                CLC
                ADC     #17
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _charincdec_L15
                LDA     gs+2
                AND     #$00FF
                TAX
                CMP     #42
                BNE     _charincdec_L15
                LDA     gs+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _charincdec_L15
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #3
                STA     9,S   ; fccstk d=0 b=9
_charincdec_L15
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
