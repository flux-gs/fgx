                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from st2d.c
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
                STA     _fcc_img0
                LDA     #rows
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #r0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #rows
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #r1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rows
                STA     gyy
                LDA     _fcc_fpr0+2
                STA     gyy+2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rows
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gw+0
                TAY
                LDA     _fcc_ptr+2
                STA     gw+2
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gw
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                INC
                STA     _fcc_img1
                LDA     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #65
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     _fcc_img1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #66
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #7
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #5
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #9
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rows
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #67
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #4
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                LDA     #3
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #68
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    r0,X
                AND     #$00FF
                TAX
                LDA     #65
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L5
                LDA     #1
                TAX
                LDA:    r0,X
                AND     #$00FF
                TAX
                LDA     #66
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L5
                LDA     #1
                BRL     _st2d_L6
_st2d_L5
                LDA     #0
_st2d_L6
                CMP     #0
                BNE     *+5
                BRL     _st2d_L3
                LDA     #2
                TAX
                LDA:    r0,X
                AND     #$00FF
                TAX
                LDA     #67
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L3
                LDA     #1
                BRL     _st2d_L4
_st2d_L3
                LDA     #0
_st2d_L4
                CMP     #0
                BNE     *+5
                BRL     _st2d_L1
                LDA     #3
                TAX
                LDA:    r0,X
                AND     #$00FF
                TAX
                LDA     #68
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L1
                LDA     #1
                BRL     _st2d_L2
_st2d_L1
                LDA     #0
_st2d_L2
                CMP     #0
                BNE     *+5
                BRL     _st2d_L0
                LDA     _fcc_img0
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_st2d_L0
                LDA     _fcc_img1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L14
                LDA     #0
                TAX
                LDA:    r1,X
                AND     #$00FF
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L14
                LDA     #1
                BRL     _st2d_L15
_st2d_L14
                LDA     #0
_st2d_L15
                CMP     #0
                BNE     *+5
                BRL     _st2d_L12
                LDA     #1
                TAX
                LDA:    r1,X
                AND     #$00FF
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L12
                LDA     #1
                BRL     _st2d_L13
_st2d_L12
                LDA     #0
_st2d_L13
                CMP     #0
                BNE     *+5
                BRL     _st2d_L10
                LDA     #2
                TAX
                LDA:    r1,X
                AND     #$00FF
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L10
                LDA     #1
                BRL     _st2d_L11
_st2d_L10
                LDA     #0
_st2d_L11
                CMP     #0
                BNE     *+5
                BRL     _st2d_L8
                LDA     #3
                TAX
                LDA:    r1,X
                AND     #$00FF
                TAX
                LDA     #20
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _st2d_L8
                LDA     #1
                BRL     _st2d_L9
_st2d_L8
                LDA     #0
_st2d_L9
                CMP     #0
                BNE     *+5
                BRL     _st2d_L7
                LDA     _fcc_img0
                TAX
                LDA     #30
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_st2d_L7
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
