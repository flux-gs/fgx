                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ampcastmember.c
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
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     h+0
                TAY
                LDA     _fcc_ptr+2
                STA     h+2
                TYA
                LDA     h+2
                STA     _fcc_fpr0+2
                LDA     h+0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     h+2
                STA     _fcc_fpr0+2
                LDA     h+0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     h+2
                STA     _fcc_fpr0+2
                LDA     h+0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img7
                LDA     _fcc_fpr0
                STA     _fcc_img6
                LDA     #11
                STA     [_fcc_img2]
                LDA     #22
                STA     [_fcc_img0]
                LDA     #$0005
                STA     _fcc_long_hi
                LDA     #$1615
                STA     [_fcc_img6]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_img6],Y
                TXA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #11
                BEQ     _ampcastmember_L0
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
_ampcastmember_L0
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #22
                BEQ     _ampcastmember_L1
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
_ampcastmember_L1
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #5653
                STX     _fcc_long_b_lo
                LDX     #5
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ampcastmember_L2
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
_ampcastmember_L2
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_fpr1+2
                LDA     _fcc_img0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ampcastmember_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ampcastmember_L4
                LDA     #1
                BRA     _ampcastmember_L5
_ampcastmember_L4
                LDA     #0
_ampcastmember_L5
                CMP     #0
                BEQ     _ampcastmember_L3
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
_ampcastmember_L3
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_img2
                TAX
                CMP     #2
                BEQ     _ampcastmember_L6
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
_ampcastmember_L6
                LDA     _fcc_img7
                STA     _fcc_fpr0+2
                LDA     _fcc_img6
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_img2
                TAX
                CMP     #4
                BEQ     _ampcastmember_L7
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
_ampcastmember_L7
                LDA     h+2
                STA     _fcc_fpr0+2
                LDA     h+0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     #99
                STA     [_fcc_img0]
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #99
                BEQ     _ampcastmember_L8
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
_ampcastmember_L8
                LDA     h+2
                STA     _fcc_fpr0+2
                LDA     h+0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #11
                BEQ     _ampcastmember_L9
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
_ampcastmember_L9
                LDA     #buf
                PHA
                LDA     #5
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #77
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
                LDA     #5
                CLC
                ADC     #buf
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img9
                LDA     _fcc_fpr0
                STA     _fcc_img8
                LDA     [_fcc_img8]
                AND     #$00FF
                TAX
                CMP     #77
                BEQ     _ampcastmember_L10
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
_ampcastmember_L10
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
main_FRAMESIZE   EQU     20
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
