                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrowdotchain.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_arrowdotchain_ob
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     #1911
                STA     [_fcc_img0]
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #4369
                STA     [_fcc_fpr0]
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #8738
                STA     [_fcc_fpr0]
                LDA     #13107
                STA     _arrowdotchain_detached+0
                LDA     #17476
                STA     _arrowdotchain_detached+2
                LDA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_arrowdotchain_detached
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     #21845
                STA     _arrowdotchain_md+0
                LDA     #0
                ASL
                CLC
                ADC     #_arrowdotchain_md+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #26208
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                CLC
                ADC     #_arrowdotchain_md+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #26209
                STA     [_fcc_fpr0]
                LDA     #2
                ASL
                CLC
                ADC     #_arrowdotchain_md+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #26210
                STA     [_fcc_fpr0]
                LDA     #3
                ASL
                CLC
                ADC     #_arrowdotchain_md+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #26211
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_arrowdotchain_md
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #10
                STA     [_fcc_img0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #12
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_arrowdotchain_ob
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _arrowdotchain_bx+0
                TAY
                LDA     _fcc_ptr+2
                STA     _arrowdotchain_bx+2
                TYA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #8738
                BEQ     _arrowdotchain_L0
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #4369
                BEQ     _arrowdotchain_L1
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L1
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                INC
                INC
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8738
                BEQ     _arrowdotchain_L2
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L2
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #4369
                BEQ     _arrowdotchain_L3
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_arrowdotchain_ob
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                INC
                INC
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8738
                BEQ     _arrowdotchain_L4
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L4
                LDA     _arrowdotchain_bx+2
                STA     _fcc_fpr0+2
                LDA     _arrowdotchain_bx
                INC
                INC
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8738
                BEQ     _arrowdotchain_L5
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L5
                LDA     _arrowdotchain_bx+2
                STA     _fcc_fpr0+2
                LDA     _arrowdotchain_bx
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #1911
                BEQ     _arrowdotchain_L6
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L6
                LDY     #6
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #17476
                BEQ     _arrowdotchain_L7
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L7
                LDY     #6
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #13107
                BEQ     _arrowdotchain_L8
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L8
                LDY     #10
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #26210
                BEQ     _arrowdotchain_L9
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L9
                LDY     #10
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #21845
                BEQ     _arrowdotchain_L10
                LDA     #60
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L10
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2989
                STA     [_fcc_fpr0]
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #2989
                BEQ     _arrowdotchain_L11
                LDA     #61
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L11
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #4369
                BEQ     _arrowdotchain_L12
                LDA     #62
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L12
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #1911
                BEQ     _arrowdotchain_L13
                LDA     #63
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L13
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #8738
                STA     [_fcc_fpr0]
                LDY     #10
                LDA     [_fcc_img0],Y
                PHA
                INY
                INY
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     [_fcc_img2]
                TAX
                CMP     #26209
                BEQ     _arrowdotchain_L14
                LDA     #64
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L14
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #26210
                BEQ     _arrowdotchain_L15
                LDA     #65
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L15
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #2748
                STA     [_fcc_fpr0]
                LDA     _arrowdotchain_md+4
                TAX
                CMP     #2748
                BEQ     _arrowdotchain_L16
                LDA     #66
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L16
                LDA     _arrowdotchain_md+2
                TAX
                CMP     #26208
                BEQ     _arrowdotchain_L17
                LDA     #67
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L17
                LDA     _arrowdotchain_md+6
                TAX
                CMP     #26210
                BEQ     _arrowdotchain_L18
                LDA     #68
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrowdotchain_L18
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
