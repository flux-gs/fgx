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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_obj
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     #7
                STA     _lvrun_bump_obj+0
                LDA     #0
                ASL
                CLC
                ADC     #_lvrun_bump_obj+6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #10
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                CLC
                ADC     #_lvrun_bump_obj+6
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
                LDA     #2
                ASL
                CLC
                ADC     #_lvrun_bump_obj+6
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
                LDA     _lvrun_bump_obj+8
                STA     _fcc_tmp_b
                INC
                STA     _lvrun_bump_obj+8
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                CMP     #20
                BNE     _lvrun_bump_L0
                LDA     _lvrun_bump_obj+8
                CMP     #21
                BNE     _lvrun_bump_L0
                LDA     _lvrun_bump_obj+6
                CMP     #10
                BNE     _lvrun_bump_L0
                LDA     _lvrun_bump_obj+10
                CMP     #30
                BNE     _lvrun_bump_L0
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L0
                LDA     #0
                CLC
                ADC     #_lvrun_bump_obj+2
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
                ADC     #_lvrun_bump_obj+2
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
                ADC     #_lvrun_bump_obj+2
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
                STA     _fcc_img2
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                CMP     #98
                BNE     _lvrun_bump_L1
                LDA     _lvrun_bump_obj+3
                AND     #$00FF
                CMP     #97
                BNE     _lvrun_bump_L1
                LDA     _lvrun_bump_obj+2
                AND     #$00FF
                CMP     #97
                BNE     _lvrun_bump_L1
                LDA     _lvrun_bump_obj+4
                AND     #$00FF
                CMP     #99
                BNE     _lvrun_bump_L1
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L1
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #100
                STA     [_fcc_fpr0]
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #200
                STA     [_fcc_fpr0]
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #300
                STA     [_fcc_fpr0]
                LDA     #1
                STA     _fcc_img2
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                CMP     #200
                BEQ     *+5
                BRL     _lvrun_bump_L2
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #201
                BNE     _lvrun_bump_L2
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #100
                BNE     _lvrun_bump_L2
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                CMP     #300
                BNE     _lvrun_bump_L2
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L2
                LDA     #40
                STA     _lvrun_bump_obj+18
                LDA     #50
                STA     _lvrun_bump_obj+20
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                CLC
                ADC     #18
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                CMP     #40
                BNE     _lvrun_bump_L3
                LDA     _lvrun_bump_obj+18
                CMP     #41
                BNE     _lvrun_bump_L3
                LDA     _lvrun_bump_obj+20
                CMP     #50
                BNE     _lvrun_bump_L3
                LDA     _lvrun_bump_obj+0
                CMP     #7
                BNE     _lvrun_bump_L3
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L3
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
                ADC     #_lvrun_bump_vs
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
                LDA     #60
                STA     [_fcc_fpr0]
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
                ADC     #_lvrun_bump_vs
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
                LDA     #70
                STA     [_fcc_fpr0]
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
                ADC     #_lvrun_bump_vs
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
                LDA     #80
                STA     [_fcc_fpr0]
                LDA     #2
                STA     _fcc_img2
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
                ADC     #_lvrun_bump_vs
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
                STA     _fcc_tmp_b
                DEC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                CMP     #60
                BEQ     *+5
                BRL     _lvrun_bump_L4
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
                ADC     #_lvrun_bump_vs
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
                CMP     #59
                BEQ     *+5
                BRL     _lvrun_bump_L4
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
                ADC     #_lvrun_bump_vs
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
                CMP     #70
                BNE     _lvrun_bump_L4
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
                ADC     #_lvrun_bump_vs
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
                CMP     #80
                BNE     _lvrun_bump_L4
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L4
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
                ADC     #_lvrun_bump_vs
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
                LDA     #3
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #5
                STA     [_fcc_fpr0]
                LDA     _lvrun_bump_vs+12
                STA     _fcc_tmp_b
                INC
                STA     _lvrun_bump_vs+12
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
                ADC     #_lvrun_bump_vs
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
                LDA     #3
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #6
                BNE     _lvrun_bump_L5
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
                ADC     #_lvrun_bump_vs
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
                BNE     _lvrun_bump_L5
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L5
                LDA     _lvrun_bump_obj+10
                DEC
                STA     _lvrun_bump_obj+10
                CMP     #29
                BNE     _lvrun_bump_L6
                LDA     _lvrun_bump_obj+8
                CMP     #21
                BNE     _lvrun_bump_L6
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L6
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     _lvrun_bump_obj+20
                CMP     #51
                BNE     _lvrun_bump_L7
                LDA     _lvrun_bump_obj+18
                CMP     #41
                BNE     _lvrun_bump_L7
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L7
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_buf
                STA     _fcc_fpr0
                PLA
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
                LDY     #14
                LDA     [_fcc_img3],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
                LDA     [_fcc_img3],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                AND     #$00FF
                LDY     #14
                LDA     [_fcc_img3],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #16
                LDA     [_fcc_img3],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                LDA     #1
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                CMP     #120
                BNE     _lvrun_bump_L8
                LDA     _fcc_img1
                CMP     #122
                BNE     _lvrun_bump_L8
                LDA     #2
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                PHA
                LDA     #122
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _lvrun_bump_L8
                LDA     #0
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                CMP     #120
                BNE     _lvrun_bump_L8
                LDA     _lvrun_bump_obj+16
                STA     _fcc_fpr0+2
                LDA     _lvrun_bump_obj+14
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_lvrun_bump_buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _lvrun_bump_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _lvrun_bump_L9
                LDA     #1
                BRA     _lvrun_bump_L10
_lvrun_bump_L9
                LDA     #0
_lvrun_bump_L10
                CMP     #0
                BEQ     _lvrun_bump_L8
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L8
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
                ADC     #_lvrun_bump_vs
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
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
                LDA     #_lvrun_bump_buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #14
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #16
                STA     [_fcc_fpr0],Y
                LDA     _lvrun_bump_vs+42
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _lvrun_bump_vs+40
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
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
                INC
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _lvrun_bump_L11
                LDA     #1
                TAX
                LDA:    _lvrun_bump_buf,X
                AND     #$00FF
                CMP     #120
                BNE     _lvrun_bump_L11
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L11
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                CLC
                ADC     #6
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #9
                STA     [_fcc_fpr0]
                INC
                STA     _fcc_img1
                CMP     #10
                BNE     _lvrun_bump_L12
                LDA     _lvrun_bump_obj+12
                CMP     #9
                BNE     _lvrun_bump_L12
                LDA     _lvrun_bump_obj+10
                CMP     #29
                BNE     _lvrun_bump_L12
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L12
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
                LDA     _lvrun_bump_m2+10
                STA     _fcc_tmp_b
                INC
                STA     _lvrun_bump_m2+10
                LDA     _fcc_tmp_b
                STA     _fcc_img1
                CMP     #3
                BNE     _lvrun_bump_L13
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
                CMP     #4
                BNE     _lvrun_bump_L13
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
                CMP     #1
                BNE     _lvrun_bump_L13
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
                CMP     #2
                BNE     _lvrun_bump_L13
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L13
                LDA     #1
                STA     _fcc_img2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #_lvrun_bump_m2
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
                LDA     #8
                STA     [_fcc_fpr0]
                INC
                STA     _fcc_img1
                CMP     #9
                BNE     _lvrun_bump_L14
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
                CMP     #8
                BNE     _lvrun_bump_L14
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
                CMP     #0
                BNE     _lvrun_bump_L14
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
                CMP     #4
                BNE     _lvrun_bump_L14
                LDA     _fcc_img0
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L14
                LDA     _lvrun_bump_m2
                STA     _fcc_tmp_b
                INC
                STA     _lvrun_bump_m2
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
                CMP     #1
                BNE     _lvrun_bump_L15
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
                CMP     #0
                BNE     _lvrun_bump_L15
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #3
                STA     _fcc_img0
_lvrun_bump_L15
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
