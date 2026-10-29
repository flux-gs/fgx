                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from declinit_ptr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f7
f7            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f7_FRAMESIZE
                DO      f7_STKGUARD
                BCC     f7_stkovf
                CMP     _fcc_stkfloor
                BCS     f7_stkok
f7_stkovf       JMP     _fcc_stkoflow
                FIN
f7_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #f7_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f7_FRAMESIZE   EQU     0
f7_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     25,S   ; fccstk d=0 b=25
                LDA     _fcc_fpr0+2
                STA     27,S   ; fccstk d=0 b=27
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_fpr0+2
                STA     31,S   ; fccstk d=0 b=31
                LDA     #0
                STA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     #0
                STA     35,S   ; fccstk d=0 b=35
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     #7
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                LDA     _declinit_ptr_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _declinit_ptr_FA0
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _declinit_ptr_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _declinit_ptr_L6
                LDA     #0
                BRL     _declinit_ptr_L7
_declinit_ptr_L6
                LDA     #1
_declinit_ptr_L7
                CMP     #0
                BEQ     *+5
                BRL     _declinit_ptr_L4
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gs2
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _declinit_ptr_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _declinit_ptr_L8
                LDA     #0
                BRL     _declinit_ptr_L9
_declinit_ptr_L8
                LDA     #1
_declinit_ptr_L9
                CMP     #0
                BEQ     *+5
                BRL     _declinit_ptr_L4
                LDA     #0
                BRL     _declinit_ptr_L5
_declinit_ptr_L4
                LDA     #1
_declinit_ptr_L5
                CMP     #0
                BEQ     *+5
                BRL     _declinit_ptr_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _declinit_ptr_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _declinit_ptr_L10
                LDA     #0
                BRL     _declinit_ptr_L11
_declinit_ptr_L10
                LDA     #1
_declinit_ptr_L11
                CMP     #0
                BEQ     *+5
                BRL     _declinit_ptr_L2
                LDA     #0
                BRL     _declinit_ptr_L3
_declinit_ptr_L2
                LDA     #1
_declinit_ptr_L3
                CMP     #0
                BNE     *+5
                BRL     _declinit_ptr_L1
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L1
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #5
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    gs2,X
                AND     #$00FF
                TAX
                TXA
                CMP     #5
                BNE     *+5
                BRL     _declinit_ptr_L12
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L12
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _declinit_ptr_L16
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _declinit_ptr_L16
                LDA     #0
                BRL     _declinit_ptr_L17
_declinit_ptr_L16
                LDA     #1
_declinit_ptr_L17
                CMP     #0
                BEQ     *+5
                BRL     _declinit_ptr_L14
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _declinit_ptr_L14
                LDA     #0
                BRL     _declinit_ptr_L15
_declinit_ptr_L14
                LDA     #1
_declinit_ptr_L15
                CMP     #0
                BNE     *+5
                BRL     _declinit_ptr_L13
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L13
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #9
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    gs1,X
                AND     #$00FF
                TAX
                TXA
                CMP     #9
                BNE     *+5
                BRL     _declinit_ptr_L18
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L18
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                PHK
                PEA     _declinit_ptr_L20-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_declinit_ptr_L20
                TAX
                TXA
                CMP     #7
                BNE     *+5
                BRL     _declinit_ptr_L19
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L19
                LDA     #10
                STA     gi
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
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                DEC
                STA     [_fcc_fpr0]
                LDA     gi
                TAX
                TXA
                CMP     #11
                BNE     *+5
                BRL     _declinit_ptr_L21
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs2
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_fpr0
                STA     15,S   ; fccstk d=0 b=15
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr0+2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    gs2,X
                AND     #$00FF
                TAX
                TXA
                CMP     #4
                BNE     *+5
                BRL     _declinit_ptr_L22
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L22
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #24
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_fpr0
                STA     19,S   ; fccstk d=0 b=19
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_fpr0+2
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     _fcc_fpr1
                LDA     #1
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _declinit_ptr_L24
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _declinit_ptr_L24
                LDA     #0
                BRL     _declinit_ptr_L25
_declinit_ptr_L24
                LDA     #1
_declinit_ptr_L25
                CMP     #0
                BNE     *+5
                BRL     _declinit_ptr_L23
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L23
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #24
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #1
                TAX
                LDA:    gs1,X
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _declinit_ptr_L26
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L26
                LDA     #1
                STA     23,S   ; fccstk d=0 b=23
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #recs
                STA     _fcc_fpr0
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #3
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #recs
                STA     _fcc_fpr0
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #400
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #recs
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _declinit_ptr_L28
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #recs
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #400
                BEQ     *+5
                BRL     _declinit_ptr_L28
                LDA     #0
                BRL     _declinit_ptr_L29
_declinit_ptr_L28
                LDA     #1
_declinit_ptr_L29
                CMP     #0
                BNE     *+5
                BRL     _declinit_ptr_L27
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L27
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #36
                STA     _fcc_fpr0
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #8
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #36
                STA     _fcc_fpr0
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #250
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #36
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _declinit_ptr_L31
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #36
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #250
                BEQ     *+5
                BRL     _declinit_ptr_L31
                LDA     #0
                BRL     _declinit_ptr_L32
_declinit_ptr_L31
                LDA     #1
_declinit_ptr_L32
                CMP     #0
                BNE     *+5
                BRL     _declinit_ptr_L30
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_declinit_ptr_L30
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     60
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
