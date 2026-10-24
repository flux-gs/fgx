                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrfield_incdec.c
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
                LDA     #10
                STA     _arrfield_incdec_obj+0
                LDA     #0
                ASL
                CLC
                ADC     #_arrfield_incdec_obj+6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #20
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                CLC
                ADC     #_arrfield_incdec_obj+6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #30
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                CLC
                ADC     #_arrfield_incdec_obj+6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #40
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                CLC
                ADC     #_arrfield_incdec_obj+6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                INC
                STA     [_fcc_fpr0]
                LDA     _arrfield_incdec_obj+8
                TAX
                TXA
                CMP     #31
                BEQ     *+5
                BRL     _arrfield_incdec_L5
                LDA     _arrfield_incdec_obj+6
                TAX
                TXA
                CMP     #20
                BEQ     *+5
                BRL     _arrfield_incdec_L5
                LDA     #1
                BRL     _arrfield_incdec_L6
_arrfield_incdec_L5
                LDA     #0
_arrfield_incdec_L6
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L3
                LDA     _arrfield_incdec_obj+10
                TAX
                TXA
                CMP     #40
                BEQ     *+5
                BRL     _arrfield_incdec_L3
                LDA     #1
                BRL     _arrfield_incdec_L4
_arrfield_incdec_L3
                LDA     #0
_arrfield_incdec_L4
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L1
                LDA     _arrfield_incdec_obj+0
                TAX
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _arrfield_incdec_L1
                LDA     #1
                BRL     _arrfield_incdec_L2
_arrfield_incdec_L1
                LDA     #0
_arrfield_incdec_L2
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L0
                LDA     #2
                STA     _fcc_img1
                ASL
                CLC
                ADC     #_arrfield_incdec_obj+6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                TXA
                DEC
                STA     [_fcc_fpr0]
                LDA     _arrfield_incdec_obj+10
                TAX
                TXA
                CMP     #39
                BEQ     *+5
                BRL     _arrfield_incdec_L10
                LDA     _arrfield_incdec_obj+8
                TAX
                TXA
                CMP     #31
                BEQ     *+5
                BRL     _arrfield_incdec_L10
                LDA     #1
                BRL     _arrfield_incdec_L11
_arrfield_incdec_L10
                LDA     #0
_arrfield_incdec_L11
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L8
                LDA     _arrfield_incdec_obj+6
                TAX
                TXA
                CMP     #20
                BEQ     *+5
                BRL     _arrfield_incdec_L8
                LDA     #1
                BRL     _arrfield_incdec_L9
_arrfield_incdec_L8
                LDA     #0
_arrfield_incdec_L9
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L7
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L7
                LDA     #0
                CLC
                ADC     #_arrfield_incdec_obj+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #97
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                CLC
                ADC     #_arrfield_incdec_obj+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #98
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #2
                CLC
                ADC     #_arrfield_incdec_obj+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #99
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                CLC
                ADC     #_arrfield_incdec_obj+2
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
                TAX
                TXA
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _arrfield_incdec_obj+3
                AND     #$00FF
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _arrfield_incdec_L15
                LDA     _arrfield_incdec_obj+2
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _arrfield_incdec_L15
                LDA     #1
                BRL     _arrfield_incdec_L16
_arrfield_incdec_L15
                LDA     #0
_arrfield_incdec_L16
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L13
                LDA     _arrfield_incdec_obj+4
                AND     #$00FF
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _arrfield_incdec_L13
                LDA     #1
                BRL     _arrfield_incdec_L14
_arrfield_incdec_L13
                LDA     #0
_arrfield_incdec_L14
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L12
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L12
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_arrfield_incdec_obj
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                INC
                STA     [_fcc_fpr0]
                LDA     _arrfield_incdec_obj+6
                TAX
                TXA
                CMP     #21
                BEQ     *+5
                BRL     _arrfield_incdec_L18
                LDA     _arrfield_incdec_obj+8
                TAX
                TXA
                CMP     #31
                BEQ     *+5
                BRL     _arrfield_incdec_L18
                LDA     #1
                BRL     _arrfield_incdec_L19
_arrfield_incdec_L18
                LDA     #0
_arrfield_incdec_L19
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L17
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L17
                LDA     #2
                STA     _fcc_img1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _arrfield_incdec_obj+4
                AND     #$00FF
                TAX
                TXA
                CMP     #98
                BEQ     *+5
                BRL     _arrfield_incdec_L23
                LDA     _arrfield_incdec_obj+3
                AND     #$00FF
                TAX
                TXA
                CMP     #99
                BEQ     *+5
                BRL     _arrfield_incdec_L23
                LDA     #1
                BRL     _arrfield_incdec_L24
_arrfield_incdec_L23
                LDA     #0
_arrfield_incdec_L24
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L21
                LDA     _arrfield_incdec_obj+2
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _arrfield_incdec_L21
                LDA     #1
                BRL     _arrfield_incdec_L22
_arrfield_incdec_L21
                LDA     #0
_arrfield_incdec_L22
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L20
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L20
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #100
                STA     [_fcc_fpr0]
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                LDA     #200
                STA     [_fcc_fpr0]
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #300
                STA     [_fcc_fpr0]
                LDA     _arrfield_incdec_vs+8
                TAX
                TXA
                CLC
                ADC     #7
                STA     _arrfield_incdec_vs+8
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #107
                BEQ     *+5
                BRL     _arrfield_incdec_L28
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                TXA
                CMP     #200
                BEQ     *+5
                BRL     _arrfield_incdec_L28
                LDA     #1
                BRL     _arrfield_incdec_L29
_arrfield_incdec_L28
                LDA     #0
_arrfield_incdec_L29
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L26
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #300
                BEQ     *+5
                BRL     _arrfield_incdec_L26
                LDA     #1
                BRL     _arrfield_incdec_L27
_arrfield_incdec_L26
                LDA     #0
_arrfield_incdec_L27
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L25
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L25
                LDA     #1
                STA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                SEC
                SBC     #50
                STA     [_fcc_fpr0]
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                BRL     _arrfield_incdec_L31
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_arrfield_incdec_vs
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
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #107
                BEQ     *+5
                BRL     _arrfield_incdec_L31
                LDA     #1
                BRL     _arrfield_incdec_L32
_arrfield_incdec_L31
                LDA     #0
_arrfield_incdec_L32
                CMP     #0
                BNE     *+5
                BRL     _arrfield_incdec_L30
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L30
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
