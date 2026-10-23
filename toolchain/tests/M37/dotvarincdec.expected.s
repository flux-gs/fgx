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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                LDA     #2
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gi
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_fpr0
                STA     11,S   ; fccstk d=0 b=11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gc
                STA     _fcc_fpr0
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L5
                LDA     gi+2
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L5
                LDA     #1
                BRL     _dotvarincdec_L6
_dotvarincdec_L5
                LDA     #0
_dotvarincdec_L6
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L3
                LDA     gi+0
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L3
                LDA     #1
                BRL     _dotvarincdec_L4
_dotvarincdec_L3
                LDA     #0
_dotvarincdec_L4
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L1
                LDA     gi+4
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L1
                LDA     #1
                BRL     _dotvarincdec_L2
_dotvarincdec_L1
                LDA     #0
_dotvarincdec_L2
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L0
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L12
                LDA     gi+2
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _dotvarincdec_L12
                LDA     #1
                BRL     _dotvarincdec_L13
_dotvarincdec_L12
                LDA     #0
_dotvarincdec_L13
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L10
                LDA     gi+0
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L10
                LDA     #1
                BRL     _dotvarincdec_L11
_dotvarincdec_L10
                LDA     #0
_dotvarincdec_L11
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L8
                LDA     gi+4
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L8
                LDA     #1
                BRL     _dotvarincdec_L9
_dotvarincdec_L8
                LDA     #0
_dotvarincdec_L9
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L7
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L7
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gi
                INC
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
                INC
                STA     [_fcc_ptr]
                STA     21,S   ; fccstk d=0 b=21
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L19
                LDA     gi+2
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L19
                LDA     #1
                BRL     _dotvarincdec_L20
_dotvarincdec_L19
                LDA     #0
_dotvarincdec_L20
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L17
                LDA     gi+0
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L17
                LDA     #1
                BRL     _dotvarincdec_L18
_dotvarincdec_L17
                LDA     #0
_dotvarincdec_L18
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L15
                LDA     gi+4
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L15
                LDA     #1
                BRL     _dotvarincdec_L16
_dotvarincdec_L15
                LDA     #0
_dotvarincdec_L16
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L14
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L14
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L26
                LDA     gc+1
                AND     #$00FF
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L26
                LDA     #1
                BRL     _dotvarincdec_L27
_dotvarincdec_L26
                LDA     #0
_dotvarincdec_L27
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L24
                LDA     gc+0
                AND     #$00FF
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L24
                LDA     #1
                BRL     _dotvarincdec_L25
_dotvarincdec_L24
                LDA     #0
_dotvarincdec_L25
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L22
                LDA     gc+2
                AND     #$00FF
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L22
                LDA     #1
                BRL     _dotvarincdec_L23
_dotvarincdec_L22
                LDA     #0
_dotvarincdec_L23
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L21
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L21
                FGX2_FARCALL clear
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gc
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
                STA     21,S   ; fccstk d=0 b=21
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L33
                LDA     gc+1
                AND     #$00FF
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L33
                LDA     #1
                BRL     _dotvarincdec_L34
_dotvarincdec_L33
                LDA     #0
_dotvarincdec_L34
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L31
                LDA     gc+0
                AND     #$00FF
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L31
                LDA     #1
                BRL     _dotvarincdec_L32
_dotvarincdec_L31
                LDA     #0
_dotvarincdec_L32
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L29
                LDA     gc+2
                AND     #$00FF
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L29
                LDA     #1
                BRL     _dotvarincdec_L30
_dotvarincdec_L29
                LDA     #0
_dotvarincdec_L30
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L28
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L28
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L40
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L40
                LDA     #1
                BRL     _dotvarincdec_L41
_dotvarincdec_L40
                LDA     #0
_dotvarincdec_L41
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L38
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _dotvarincdec_L38
                LDA     #1
                BRL     _dotvarincdec_L39
_dotvarincdec_L38
                LDA     #0
_dotvarincdec_L39
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L36
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _dotvarincdec_L36
                LDA     #1
                BRL     _dotvarincdec_L37
_dotvarincdec_L36
                LDA     #0
_dotvarincdec_L37
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L35
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L35
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L47
                LDA     8,S   ; fccstk d=0 b=8
                AND     #$00FF
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L47
                LDA     #1
                BRL     _dotvarincdec_L48
_dotvarincdec_L47
                LDA     #0
_dotvarincdec_L48
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L45
                LDA     7,S   ; fccstk d=0 b=7
                AND     #$00FF
                TAX
                TXA
                CMP     #113
                BEQ     *+5
                BRL     _dotvarincdec_L45
                LDA     #1
                BRL     _dotvarincdec_L46
_dotvarincdec_L45
                LDA     #0
_dotvarincdec_L46
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L43
                LDA     9,S   ; fccstk d=0 b=9
                AND     #$00FF
                TAX
                TXA
                CMP     #115
                BEQ     *+5
                BRL     _dotvarincdec_L43
                LDA     #1
                BRL     _dotvarincdec_L44
_dotvarincdec_L43
                LDA     #0
_dotvarincdec_L44
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L42
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L42
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
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _dotvarincdec_L52
                LDA     clocks+0
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _dotvarincdec_L52
                LDA     #1
                BRL     _dotvarincdec_L53
_dotvarincdec_L52
                LDA     #0
_dotvarincdec_L53
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L50
                LDA     clocks+4
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _dotvarincdec_L50
                LDA     #1
                BRL     _dotvarincdec_L51
_dotvarincdec_L50
                LDA     #0
_dotvarincdec_L51
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L49
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L49
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L59
                LDA     gi+2
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L59
                LDA     #1
                BRL     _dotvarincdec_L60
_dotvarincdec_L59
                LDA     #0
_dotvarincdec_L60
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L57
                LDA     gi+0
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L57
                LDA     #1
                BRL     _dotvarincdec_L58
_dotvarincdec_L57
                LDA     #0
_dotvarincdec_L58
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L55
                LDA     gi+4
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L55
                LDA     #1
                BRL     _dotvarincdec_L56
_dotvarincdec_L55
                LDA     #0
_dotvarincdec_L56
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L54
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L54
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L66
                LDA     gc+1
                AND     #$00FF
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L66
                LDA     #1
                BRL     _dotvarincdec_L67
_dotvarincdec_L66
                LDA     #0
_dotvarincdec_L67
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L64
                LDA     gc+0
                AND     #$00FF
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L64
                LDA     #1
                BRL     _dotvarincdec_L65
_dotvarincdec_L64
                LDA     #0
_dotvarincdec_L65
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L62
                LDA     gc+2
                AND     #$00FF
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L62
                LDA     #1
                BRL     _dotvarincdec_L63
_dotvarincdec_L62
                LDA     #0
_dotvarincdec_L63
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L61
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L61
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                LDA     #2
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _dotvarincdec_L75
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _dotvarincdec_L75
                LDA     #1
                BRL     _dotvarincdec_L76
_dotvarincdec_L75
                LDA     #0
_dotvarincdec_L76
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L73
                LDA     gp+4
                STA     _fcc_fpr0+2
                LDA     gp+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                LDA     #3
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _dotvarincdec_L77
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _dotvarincdec_L77
                LDA     #1
                BRL     _dotvarincdec_L78
_dotvarincdec_L77
                LDA     #0
_dotvarincdec_L78
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L73
                LDA     #1
                BRL     _dotvarincdec_L74
_dotvarincdec_L73
                LDA     #0
_dotvarincdec_L74
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L71
                LDA     gp+0
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L71
                LDA     #1
                BRL     _dotvarincdec_L72
_dotvarincdec_L71
                LDA     #0
_dotvarincdec_L72
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L69
                LDA     gp+6
                TAX
                TXA
                CMP     #67
                BEQ     *+5
                BRL     _dotvarincdec_L69
                LDA     #1
                BRL     _dotvarincdec_L70
_dotvarincdec_L69
                LDA     #0
_dotvarincdec_L70
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L68
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L68
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
                TXA
                CMP     #33
                BEQ     *+5
                BRL     _dotvarincdec_L82
                LDA     gp+4
                STA     _fcc_fpr0+2
                LDA     gp+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #34
                BEQ     *+5
                BRL     _dotvarincdec_L82
                LDA     #1
                BRL     _dotvarincdec_L83
_dotvarincdec_L82
                LDA     #0
_dotvarincdec_L83
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L80
                LDA     gp+0
                TAX
                TXA
                CMP     #65
                BEQ     *+5
                BRL     _dotvarincdec_L80
                LDA     #1
                BRL     _dotvarincdec_L81
_dotvarincdec_L80
                LDA     #0
_dotvarincdec_L81
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L79
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L79
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L91
                LDA     gn+2
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L91
                LDA     #1
                BRL     _dotvarincdec_L92
_dotvarincdec_L91
                LDA     #0
_dotvarincdec_L92
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L89
                LDA     gn+0
                TAX
                TXA
                CMP     #81
                BEQ     *+5
                BRL     _dotvarincdec_L89
                LDA     #1
                BRL     _dotvarincdec_L90
_dotvarincdec_L89
                LDA     #0
_dotvarincdec_L90
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L87
                LDA     gn+4
                TAX
                TXA
                CMP     #83
                BEQ     *+5
                BRL     _dotvarincdec_L87
                LDA     #1
                BRL     _dotvarincdec_L88
_dotvarincdec_L87
                LDA     #0
_dotvarincdec_L88
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L85
                LDA     gn+6
                TAX
                TXA
                CMP     #84
                BEQ     *+5
                BRL     _dotvarincdec_L85
                LDA     #1
                BRL     _dotvarincdec_L86
_dotvarincdec_L85
                LDA     #0
_dotvarincdec_L86
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L84
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L84
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
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _dotvarincdec_L100
                LDA     gi+2
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _dotvarincdec_L100
                LDA     #1
                BRL     _dotvarincdec_L101
_dotvarincdec_L100
                LDA     #0
_dotvarincdec_L101
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L98
                LDA     gi+0
                TAX
                TXA
                CMP     #256
                BEQ     *+5
                BRL     _dotvarincdec_L98
                LDA     #1
                BRL     _dotvarincdec_L99
_dotvarincdec_L98
                LDA     #0
_dotvarincdec_L99
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L96
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #49
                BEQ     *+5
                BRL     _dotvarincdec_L96
                LDA     #1
                BRL     _dotvarincdec_L97
_dotvarincdec_L96
                LDA     #0
_dotvarincdec_L97
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L94
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #50
                BEQ     *+5
                BRL     _dotvarincdec_L94
                LDA     #1
                BRL     _dotvarincdec_L95
_dotvarincdec_L94
                LDA     #0
_dotvarincdec_L95
                CMP     #0
                BNE     *+5
                BRL     _dotvarincdec_L93
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CLC
                ADC     #3
                STA     19,S   ; fccstk d=0 b=19
_dotvarincdec_L93
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
