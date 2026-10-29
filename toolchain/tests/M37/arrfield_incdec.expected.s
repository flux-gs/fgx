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
                INC
                STA     [_fcc_fpr0]
                LDA     _arrfield_incdec_obj+8
                CMP     #31
                BNE     _arrfield_incdec_L0
                LDA     _arrfield_incdec_obj+6
                CMP     #20
                BNE     _arrfield_incdec_L0
                LDA     _arrfield_incdec_obj+10
                CMP     #40
                BNE     _arrfield_incdec_L0
                LDA     _arrfield_incdec_obj+0
                CMP     #10
                BNE     _arrfield_incdec_L0
                LDA     _fcc_img0
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
                DEC
                STA     [_fcc_fpr0]
                LDA     _arrfield_incdec_obj+10
                CMP     #39
                BNE     _arrfield_incdec_L1
                LDA     _arrfield_incdec_obj+8
                CMP     #31
                BNE     _arrfield_incdec_L1
                LDA     _arrfield_incdec_obj+6
                CMP     #20
                BNE     _arrfield_incdec_L1
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L1
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
                INC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _arrfield_incdec_obj+3
                AND     #$00FF
                CMP     #99
                BNE     _arrfield_incdec_L2
                LDA     _arrfield_incdec_obj+2
                AND     #$00FF
                CMP     #97
                BNE     _arrfield_incdec_L2
                LDA     _arrfield_incdec_obj+4
                AND     #$00FF
                CMP     #99
                BNE     _arrfield_incdec_L2
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L2
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
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     _arrfield_incdec_obj+6
                CMP     #21
                BNE     _arrfield_incdec_L3
                LDA     _arrfield_incdec_obj+8
                CMP     #31
                BNE     _arrfield_incdec_L3
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L3
                LDA     #2
                STA     _fcc_img1
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                DEC
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _arrfield_incdec_obj+4
                AND     #$00FF
                CMP     #98
                BNE     _arrfield_incdec_L4
                LDA     _arrfield_incdec_obj+3
                AND     #$00FF
                CMP     #99
                BNE     _arrfield_incdec_L4
                LDA     _arrfield_incdec_obj+2
                AND     #$00FF
                CMP     #97
                BNE     _arrfield_incdec_L4
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L4
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
                CMP     #107
                BNE     _arrfield_incdec_L5
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
                CMP     #200
                BNE     _arrfield_incdec_L5
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
                CMP     #300
                BNE     _arrfield_incdec_L5
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L5
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
                CMP     #250
                BNE     _arrfield_incdec_L6
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
                CMP     #107
                BNE     _arrfield_incdec_L6
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_arrfield_incdec_L6
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
