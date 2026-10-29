                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from signed_char.c
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
                LDA     c
                AND     #$00FF
                AND     #$00FF
                EOR     #$0080
                SEC
                SBC     #$0080
                BPL     _signed_char_L0
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_signed_char_L0
                LDA     c
                AND     #$00FF
                AND     #$00FF
                EOR     #$0080
                SEC
                SBC     #$0080
                CMP     #$FFF0
                BNE     _signed_char_L1
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_signed_char_L1
                LDA     u
                AND     #$00FF
                AND     #$00FF
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _signed_char_L3
                EOR     #$8000
_signed_char_L3
                BPL     _signed_char_L2
                LDA     u
                AND     #$00FF
                AND     #$00FF
                CMP     #240
                BNE     _signed_char_L2
                LDA     _fcc_img0
                CLC
                ADC     #10
                STA     _fcc_img0
_signed_char_L2
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                AND     #$00FF
                EOR     #$0080
                SEC
                SBC     #$0080
                CMP     #$FF80
                BNE     _signed_char_L4
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_signed_char_L4
                LDA     #255
                STA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                AND     #$00FF
                EOR     #$0080
                SEC
                SBC     #$0080
                CMP     #$FFFF
                BNE     _signed_char_L5
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_signed_char_L5
                LDA     #255
                SEP     #$20
                MX      %10
                STA     u
                REP     #$20
                MX      %00
                AND     #$00FF
                AND     #$00FF
                TAX
                CMP     #255
                BNE     _signed_char_L6
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_signed_char_L6
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
