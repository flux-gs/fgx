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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     25,S   ; fccstk d=0 b=25
                LDA     _fcc_fpr0+2
                STA     27,S   ; fccstk d=0 b=27
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs2
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_fpr0+2
                STA     31,S   ; fccstk d=0 b=31
                LDA     #0
                STA     33,S   ; fccstk d=0 b=33
                TAY
                LDA     #0
                STA     35,S   ; fccstk d=0 b=35
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _declinit_ptr_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _declinit_ptr_L3
                LDA     #0
                BRA     _declinit_ptr_L4
_declinit_ptr_L3
                LDA     #1
_declinit_ptr_L4
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gs2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _declinit_ptr_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _declinit_ptr_L5
                LDA     #0
                BRA     _declinit_ptr_L6
_declinit_ptr_L5
                LDA     #1
_declinit_ptr_L6
                CMP     #0
                BNE     _declinit_ptr_L2
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
                BNE     _declinit_ptr_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _declinit_ptr_L7
                LDA     #0
                BRA     _declinit_ptr_L8
_declinit_ptr_L7
                LDA     #1
_declinit_ptr_L8
                CMP     #0
                BEQ     _declinit_ptr_L1
_declinit_ptr_L2
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
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
                CMP     #5
                BEQ     _declinit_ptr_L9
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gs1
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _declinit_ptr_L12
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _declinit_ptr_L12
                LDA     #0
                BRA     _declinit_ptr_L13
_declinit_ptr_L12
                LDA     #1
_declinit_ptr_L13
                CMP     #0
                BNE     _declinit_ptr_L11
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #7
                BEQ     _declinit_ptr_L10
_declinit_ptr_L11
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L10
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
                CMP     #9
                BEQ     _declinit_ptr_L14
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L14
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                PHK
                PEA     _declinit_ptr_L16-1
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
_declinit_ptr_L16
                TAX
                CMP     #7
                BEQ     _declinit_ptr_L15
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L15
                LDA     #10
                STA     gi
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
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     [_fcc_fpr0]
                DEC
                STA     [_fcc_fpr0]
                LDA     gi
                TAX
                CMP     #11
                BEQ     _declinit_ptr_L17
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L17
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs2
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     17,S   ; fccstk d=0 b=17
                LDA     _fcc_fpr0
                STA     15,S   ; fccstk d=0 b=15
                LDA     [_fcc_fpr0]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
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
                CMP     #4
                BEQ     _declinit_ptr_L18
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L18
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
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     [_fcc_img16]
                INC
                STA     [_fcc_img16]
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
                LDA     #1
                CLC
                ADC     #gs1
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _declinit_ptr_L20
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _declinit_ptr_L20
                LDA     #0
                BRA     _declinit_ptr_L21
_declinit_ptr_L20
                LDA     #1
_declinit_ptr_L21
                CMP     #0
                BEQ     _declinit_ptr_L19
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L19
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
                BEQ     _declinit_ptr_L22
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L22
                LDA     #1
                STA     23,S   ; fccstk d=0 b=23
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #recs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
                REP     #$20
                MX      %00
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #recs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     #recs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
                CMP     #3
                BNE     _declinit_ptr_L24
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     #recs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
                CMP     #400
                BEQ     _declinit_ptr_L23
_declinit_ptr_L24
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_declinit_ptr_L23
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
                CMP     #8
                BNE     _declinit_ptr_L26
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
                CMP     #250
                BEQ     _declinit_ptr_L25
_declinit_ptr_L26
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_declinit_ptr_L25
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
main_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     64
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
