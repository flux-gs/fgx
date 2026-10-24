                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dotvarincdec.c
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
                STA     gi+0
                LDA     #4
                STA     gi+2
                LDA     #67
                STA     gi+4
                LDA     #65
                SEP     #$20
                MX      %10
                STA     gc+0
                REP     #$20
                MX      %00
                LDA     #4
                SEP     #$20
                MX      %10
                STA     gc+1
                REP     #$20
                MX      %00
                LDA     #67
                SEP     #$20
                MX      %10
                STA     gc+2
                REP     #$20
                MX      %00
                LDA     #65
                STA     gp+0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf+2
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gp+2
                TAY
                LDA     _fcc_ptr+2
                STA     gp+4
                TYA
                LDA     #67
                STA     gp+6
                LDA     #81
                STA     gn+0
                LDA     #4
                STA     gn+2
                LDA     #83
                STA     gn+4
                LDA     #84
                STA     gn+6
                LDA     #7
                STA     clocks+0
                LDA     #0
                STA     clocks+2
                LDA     #0
                STA     clocks+4
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
                STA     19,S   ; fccstk d=0 b=19
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gi
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_fpr0
                STA     11,S   ; fccstk d=0 b=11
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gc
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_fpr0
                STA     15,S   ; fccstk d=0 b=15
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gi
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L0
                LDA     gi+2
                TAX
                CMP     #5
                BNE     _dotvarincdec_L0
                LDA     gi+0
                TAX
                CMP     #65
                BNE     _dotvarincdec_L0
                LDA     gi+4
                TAX
                CMP     #67
                BNE     _dotvarincdec_L0
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L0
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gi
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                DEC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L1
                LDA     gi+2
                TAX
                CMP     #3
                BNE     _dotvarincdec_L1
                LDA     gi+0
                TAX
                CMP     #65
                BNE     _dotvarincdec_L1
                LDA     gi+4
                TAX
                CMP     #67
                BNE     _dotvarincdec_L1
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L1
                FGX2_FARCALL clear
                LDA     gi+2
                INC
                STA     gi+2
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #5
                BNE     _dotvarincdec_L2
                LDA     gi+2
                TAX
                CMP     #5
                BNE     _dotvarincdec_L2
                LDA     gi+0
                TAX
                CMP     #65
                BNE     _dotvarincdec_L2
                LDA     gi+4
                TAX
                CMP     #67
                BNE     _dotvarincdec_L2
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L2
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gc
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
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L3
                LDA     gc+1
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _dotvarincdec_L3
                LDA     gc+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _dotvarincdec_L3
                LDA     gc+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _dotvarincdec_L3
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L3
                FGX2_FARCALL clear
                LDA     gc+1
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     gc+1
                REP     #$20
                MX      %00
                AND     #$00FF
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #5
                BNE     _dotvarincdec_L4
                LDA     gc+1
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _dotvarincdec_L4
                LDA     gc+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _dotvarincdec_L4
                LDA     gc+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _dotvarincdec_L4
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L4
                LDA     #97
                STA     1,S   ; fccstk d=0 b=1
                LDA     #4
                STA     3,S   ; fccstk d=0 b=3
                LDA     #99
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L5
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #5
                BNE     _dotvarincdec_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #97
                BNE     _dotvarincdec_L5
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #99
                BNE     _dotvarincdec_L5
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L5
                LDA     #113
                SEP     #$20
                MX      %10
                STA     7,S   ; fccstk d=0 b=7
                REP     #$20
                MX      %00
                LDA     #4
                SEP     #$20
                MX      %10
                STA     8,S   ; fccstk d=0 b=8
                REP     #$20
                MX      %00
                LDA     #115
                SEP     #$20
                MX      %10
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
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
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L6
                LDA     8,S   ; fccstk d=0 b=8
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _dotvarincdec_L6
                LDA     7,S   ; fccstk d=0 b=7
                AND     #$00FF
                TAX
                CMP     #113
                BNE     _dotvarincdec_L6
                LDA     9,S   ; fccstk d=0 b=9
                AND     #$00FF
                TAX
                CMP     #115
                BNE     _dotvarincdec_L6
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L6
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #clocks
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     clocks+2
                TAX
                CMP     #7
                BNE     _dotvarincdec_L7
                LDA     clocks+0
                TAX
                CMP     #8
                BNE     _dotvarincdec_L7
                LDA     clocks+4
                BNE     _dotvarincdec_L7
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L7
                FGX2_FARCALL clear
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_ptr+2
                LDA     11,S   ; fccstk d=0 b=11
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L8
                LDA     gi+2
                TAX
                CMP     #5
                BNE     _dotvarincdec_L8
                LDA     gi+0
                TAX
                CMP     #65
                BNE     _dotvarincdec_L8
                LDA     gi+4
                TAX
                CMP     #67
                BNE     _dotvarincdec_L8
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L8
                FGX2_FARCALL clear
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_ptr+2
                LDA     15,S   ; fccstk d=0 b=15
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
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L9
                LDA     gc+1
                AND     #$00FF
                TAX
                CMP     #5
                BNE     _dotvarincdec_L9
                LDA     gc+0
                AND     #$00FF
                TAX
                CMP     #65
                BNE     _dotvarincdec_L9
                LDA     gc+2
                AND     #$00FF
                TAX
                CMP     #67
                BNE     _dotvarincdec_L9
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L9
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gp
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf+2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dotvarincdec_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dotvarincdec_L11
                LDA     #1
                BRA     _dotvarincdec_L12
_dotvarincdec_L11
                LDA     #0
_dotvarincdec_L12
                CMP     #0
                BEQ     _dotvarincdec_L10
                LDA     gp+4
                STA     _fcc_fpr0+2
                LDA     gp+2
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf+3
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dotvarincdec_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dotvarincdec_L13
                LDA     #1
                BRA     _dotvarincdec_L14
_dotvarincdec_L13
                LDA     #0
_dotvarincdec_L14
                CMP     #0
                BEQ     _dotvarincdec_L10
                LDA     gp+0
                TAX
                CMP     #65
                BNE     _dotvarincdec_L10
                LDA     gp+6
                TAX
                CMP     #67
                BNE     _dotvarincdec_L10
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L10
                FGX2_FARCALL clear
                LDA     #buf
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #33
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
                LDA     #buf
                PHA
                LDA     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #34
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gp
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #33
                BNE     _dotvarincdec_L15
                LDA     gp+4
                STA     _fcc_fpr0+2
                LDA     gp+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #34
                BNE     _dotvarincdec_L15
                LDA     gp+0
                TAX
                CMP     #65
                BNE     _dotvarincdec_L15
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L15
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gn
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L16
                LDA     gn+2
                TAX
                CMP     #5
                BNE     _dotvarincdec_L16
                LDA     gn+0
                TAX
                CMP     #81
                BNE     _dotvarincdec_L16
                LDA     gn+4
                TAX
                CMP     #83
                BNE     _dotvarincdec_L16
                LDA     gn+6
                TAX
                CMP     #84
                BNE     _dotvarincdec_L16
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L16
                FGX2_FARCALL clear
                LDA     #buf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #49
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
                LDA     #buf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #50
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
                LDA     #256
                STA     gi+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gi
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #4
                BNE     _dotvarincdec_L17
                LDA     gi+2
                TAX
                CMP     #5
                BNE     _dotvarincdec_L17
                LDA     gi+0
                TAX
                CMP     #256
                BNE     _dotvarincdec_L17
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #49
                BNE     _dotvarincdec_L17
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #50
                BNE     _dotvarincdec_L17
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L17
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     22
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 15
