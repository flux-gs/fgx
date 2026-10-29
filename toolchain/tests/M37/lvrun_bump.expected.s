                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from lvrun_bump.c
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #7
                STA     _lvrun_bump_obj+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #10
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #20
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #30
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #1
                ASL
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
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                TXA
                CMP     #20
                BEQ     *+5
                BRL     _lvrun_bump_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #21
                BEQ     *+5
                BRL     _lvrun_bump_L5
                LDA     #1
                BRL     _lvrun_bump_L6
_lvrun_bump_L5
                LDA     #0
_lvrun_bump_L6
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #10
                BEQ     *+5
                BRL     _lvrun_bump_L3
                LDA     #1
                BRL     _lvrun_bump_L4
_lvrun_bump_L3
                LDA     #0
_lvrun_bump_L4
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #30
                BEQ     *+5
                BRL     _lvrun_bump_L1
                LDA     #1
                BRL     _lvrun_bump_L2
_lvrun_bump_L1
                LDA     #0
_lvrun_bump_L2
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #97
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #98
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #99
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                STA     _fcc_img2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img2
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
                STA     _fcc_tmp_b
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                TXA
                CMP     #98
                BEQ     *+5
                BRL     _lvrun_bump_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _lvrun_bump_L12
                LDA     #1
                BRL     _lvrun_bump_L13
_lvrun_bump_L12
                LDA     #0
_lvrun_bump_L13
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L10
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #97
                BEQ     *+5
                BRL     _lvrun_bump_L10
                LDA     #1
                BRL     _lvrun_bump_L11
_lvrun_bump_L10
                LDA     #0
_lvrun_bump_L11
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L8
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #99
                BEQ     *+5
                BRL     _lvrun_bump_L8
                LDA     #1
                BRL     _lvrun_bump_L9
_lvrun_bump_L8
                LDA     #0
_lvrun_bump_L9
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L7
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #100
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #200
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #300
                STA     [_fcc_fpr0]
                LDA     #1
                STA     _fcc_img2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
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
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                TXA
                CMP     #200
                BEQ     *+5
                BRL     _lvrun_bump_L19
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #201
                BEQ     *+5
                BRL     _lvrun_bump_L19
                LDA     #1
                BRL     _lvrun_bump_L20
_lvrun_bump_L19
                LDA     #0
_lvrun_bump_L20
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L17
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #100
                BEQ     *+5
                BRL     _lvrun_bump_L17
                LDA     #1
                BRL     _lvrun_bump_L18
_lvrun_bump_L17
                LDA     #0
_lvrun_bump_L18
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #300
                BEQ     *+5
                BRL     _lvrun_bump_L15
                LDA     #1
                BRL     _lvrun_bump_L16
_lvrun_bump_L15
                LDA     #0
_lvrun_bump_L16
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L14
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L14
                LDA     #40
                STA     _lvrun_bump_obj+18
                LDA     #50
                STA     _lvrun_bump_obj+20
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                CLC
                ADC     #18
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
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                TXA
                CMP     #40
                BEQ     *+5
                BRL     _lvrun_bump_L26
                LDA     _lvrun_bump_obj+18
                TAX
                TXA
                CMP     #41
                BEQ     *+5
                BRL     _lvrun_bump_L26
                LDA     #1
                BRL     _lvrun_bump_L27
_lvrun_bump_L26
                LDA     #0
_lvrun_bump_L27
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L24
                LDA     _lvrun_bump_obj+20
                TAX
                TXA
                CMP     #50
                BEQ     *+5
                BRL     _lvrun_bump_L24
                LDA     #1
                BRL     _lvrun_bump_L25
_lvrun_bump_L24
                LDA     #0
_lvrun_bump_L25
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L22
                LDA     _lvrun_bump_obj+0
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _lvrun_bump_L22
                LDA     #1
                BRL     _lvrun_bump_L23
_lvrun_bump_L22
                LDA     #0
_lvrun_bump_L23
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L21
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                LDA     #60
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                LDA     #70
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                LDA     #80
                STA     [_fcc_fpr0]
                LDA     #2
                STA     _fcc_img2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                DEC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                TXA
                CMP     #60
                BEQ     *+5
                BRL     _lvrun_bump_L33
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                CMP     #59
                BEQ     *+5
                BRL     _lvrun_bump_L33
                LDA     #1
                BRL     _lvrun_bump_L34
_lvrun_bump_L33
                LDA     #0
_lvrun_bump_L34
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                CMP     #70
                BEQ     *+5
                BRL     _lvrun_bump_L31
                LDA     #1
                BRL     _lvrun_bump_L32
_lvrun_bump_L31
                LDA     #0
_lvrun_bump_L32
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L29
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                CMP     #80
                BEQ     *+5
                BRL     _lvrun_bump_L29
                LDA     #1
                BRL     _lvrun_bump_L30
_lvrun_bump_L29
                LDA     #0
_lvrun_bump_L30
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L28
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L28
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #3
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #5
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #3
                ASL
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
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #3
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #6
                BEQ     *+5
                BRL     _lvrun_bump_L36
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                CMP     #0
                BEQ     *+5
                BRL     _lvrun_bump_L36
                LDA     #1
                BRL     _lvrun_bump_L37
_lvrun_bump_L36
                LDA     #0
_lvrun_bump_L37
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L35
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L35
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #2
                ASL
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
                DEC
                STA     [_fcc_ptr]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #29
                BEQ     *+5
                BRL     _lvrun_bump_L39
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #21
                BEQ     *+5
                BRL     _lvrun_bump_L39
                LDA     #1
                BRL     _lvrun_bump_L40
_lvrun_bump_L39
                LDA     #0
_lvrun_bump_L40
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L38
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L38
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     _lvrun_bump_obj+20
                TAX
                TXA
                CMP     #51
                BEQ     *+5
                BRL     _lvrun_bump_L42
                LDA     _lvrun_bump_obj+18
                TAX
                TXA
                CMP     #41
                BEQ     *+5
                BRL     _lvrun_bump_L42
                LDA     #1
                BRL     _lvrun_bump_L43
_lvrun_bump_L42
                LDA     #0
_lvrun_bump_L43
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L41
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L41
                LDA     #_lvrun_bump_buf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #120
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
                LDA     #_lvrun_bump_buf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #121
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
                LDA     #_lvrun_bump_buf
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #122
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
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_buf
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _lvrun_bump_obj+14
                TAY
                LDA     _fcc_ptr+2
                STA     _lvrun_bump_obj+16
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
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
                STA     _fcc_img1
                LDA     #1
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BEQ     *+5
                BRL     _lvrun_bump_L51
                LDA     _fcc_img1
                TAX
                TXA
                CMP     #122
                BEQ     *+5
                BRL     _lvrun_bump_L51
                LDA     #1
                BRL     _lvrun_bump_L52
_lvrun_bump_L51
                LDA     #0
_lvrun_bump_L52
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L49
                LDA     #2
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                PHA
                LDA     #122
                TAX
                TXA
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _lvrun_bump_L49
                LDA     #1
                BRL     _lvrun_bump_L50
_lvrun_bump_L49
                LDA     #0
_lvrun_bump_L50
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L47
                LDA     #0
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BEQ     *+5
                BRL     _lvrun_bump_L47
                LDA     #1
                BRL     _lvrun_bump_L48
_lvrun_bump_L47
                LDA     #0
_lvrun_bump_L48
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L45
                LDA     _lvrun_bump_obj+16
                STA     _fcc_fpr0+2
                LDA     _lvrun_bump_obj+14
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_buf
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _lvrun_bump_L53
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _lvrun_bump_L53
                LDA     #1
                BRL     _lvrun_bump_L54
_lvrun_bump_L53
                LDA     #0
_lvrun_bump_L54
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L45
                LDA     #1
                BRL     _lvrun_bump_L46
_lvrun_bump_L45
                LDA     #0
_lvrun_bump_L46
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L44
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L44
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_buf
                STA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_fpr0],Y
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_vs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
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
                TXA
                INC
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                PHA
                LDA     #120
                TAX
                TXA
                INC
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _lvrun_bump_L56
                LDA     #1
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BEQ     *+5
                BRL     _lvrun_bump_L56
                LDA     #1
                BRL     _lvrun_bump_L57
_lvrun_bump_L56
                LDA     #0
_lvrun_bump_L57
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L55
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L55
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #3
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #9
                STA     [_fcc_fpr0]
                TAX
                TXA
                INC
                STA     _fcc_img1
                TAX
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _lvrun_bump_L61
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #3
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #9
                BEQ     *+5
                BRL     _lvrun_bump_L61
                LDA     #1
                BRL     _lvrun_bump_L62
_lvrun_bump_L61
                LDA     #0
_lvrun_bump_L62
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L59
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
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
                CMP     #29
                BEQ     *+5
                BRL     _lvrun_bump_L59
                LDA     #1
                BRL     _lvrun_bump_L60
_lvrun_bump_L59
                LDA     #0
_lvrun_bump_L60
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L58
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L58
                LDA     #_lvrun_bump_m2
                PHA
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_lvrun_bump_m2
                PHA
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_lvrun_bump_m2
                PHA
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #3
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_m2
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #2
                ASL
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
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _lvrun_bump_L68
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _lvrun_bump_L68
                LDA     #1
                BRL     _lvrun_bump_L69
_lvrun_bump_L68
                LDA     #0
_lvrun_bump_L69
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L66
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _lvrun_bump_L66
                LDA     #1
                BRL     _lvrun_bump_L67
_lvrun_bump_L66
                LDA     #0
_lvrun_bump_L67
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L64
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _lvrun_bump_L64
                LDA     #1
                BRL     _lvrun_bump_L65
_lvrun_bump_L64
                LDA     #0
_lvrun_bump_L65
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L63
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L63
                LDA     #1
                STA     _fcc_img2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_m2
                STA     _fcc_fpr0
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #8
                STA     [_fcc_fpr0]
                TAX
                TXA
                INC
                STA     _fcc_img1
                TAX
                TXA
                CMP     #9
                BEQ     *+5
                BRL     _lvrun_bump_L75
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _lvrun_bump_L75
                LDA     #1
                BRL     _lvrun_bump_L76
_lvrun_bump_L75
                LDA     #0
_lvrun_bump_L76
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L73
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _lvrun_bump_L73
                LDA     #1
                BRL     _lvrun_bump_L74
_lvrun_bump_L73
                LDA     #0
_lvrun_bump_L74
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L71
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _lvrun_bump_L71
                LDA     #1
                BRL     _lvrun_bump_L72
_lvrun_bump_L71
                LDA     #0
_lvrun_bump_L72
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L70
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L70
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_m2
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                ASL
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
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _lvrun_bump_L78
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _lvrun_bump_m2,X
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _lvrun_bump_L78
                LDA     #1
                BRL     _lvrun_bump_L79
_lvrun_bump_L78
                LDA     #0
_lvrun_bump_L79
                CMP     #0
                BNE     *+5
                BRL     _lvrun_bump_L77
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L77
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
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
