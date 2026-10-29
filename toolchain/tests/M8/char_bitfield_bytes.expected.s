                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from char_bitfield_bytes.c
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
                LDA     #20
                TAX
                TXA
                CMP     #20
                BNE     *+5
                BRL     _char_bitfield_bytes_L0
                LDA     _fcc_img0
                TAX
                TXA
                ORA     #1
                STA     _fcc_img0
_char_bitfield_bytes_L0
                LDA     #90
                SEP     #$20
                MX      %10
                STA     10,S   ; fccstk d=0 b=10
                REP     #$20
                MX      %00
                LDA     9,S   ; fccstk d=0 b=9
                AND     #$FFF0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #5
                AND     #$000F
                ORA     9,S   ; fccstk d=0 b=9
                STA     9,S   ; fccstk d=0 b=9
                AND     #$FF0F
                STA     9,S   ; fccstk d=0 b=9
                LDA     #4
                AND     #$000F
                ASL
                ASL
                ASL
                ASL
                ORA     9,S   ; fccstk d=0 b=9
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #69
                BEQ     *+5
                BRL     _char_bitfield_bytes_L2
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _char_bitfield_bytes_L2
                LDA     #0
                BRL     _char_bitfield_bytes_L3
_char_bitfield_bytes_L2
                LDA     #1
_char_bitfield_bytes_L3
                CMP     #0
                BNE     *+5
                BRL     _char_bitfield_bytes_L1
                LDA     _fcc_img0
                TAX
                TXA
                ORA     #2
                STA     _fcc_img0
_char_bitfield_bytes_L1
                LDA     9,S   ; fccstk d=0 b=9
                AND     #$000F
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _char_bitfield_bytes_L7
                LDA     9,S   ; fccstk d=0 b=9
                LSR
                LSR
                LSR
                LSR
                AND     #$000F
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _char_bitfield_bytes_L7
                LDA     #0
                BRL     _char_bitfield_bytes_L8
_char_bitfield_bytes_L7
                LDA     #1
_char_bitfield_bytes_L8
                CMP     #0
                BEQ     *+5
                BRL     _char_bitfield_bytes_L5
                LDA     10,S   ; fccstk d=0 b=10
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _char_bitfield_bytes_L5
                LDA     #0
                BRL     _char_bitfield_bytes_L6
_char_bitfield_bytes_L5
                LDA     #1
_char_bitfield_bytes_L6
                CMP     #0
                BNE     *+5
                BRL     _char_bitfield_bytes_L4
                LDA     _fcc_img0
                TAX
                TXA
                ORA     #4
                STA     _fcc_img0
_char_bitfield_bytes_L4
                LDA     gh+0
                AND     #$FFF0
                STA     gh+0
                LDA     #6
                AND     #$000F
                ORA     gh+0
                STA     gh+0
                AND     #$FF0F
                STA     gh+0
                LDA     #4
                AND     #$000F
                ASL
                ASL
                ASL
                ASL
                ORA     gh+0
                STA     gh+0
                LDA     #1
                SEP     #$20
                MX      %10
                STA     gh+1
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #70
                BEQ     *+5
                BRL     _char_bitfield_bytes_L10
                LDA     gh+1
                AND     #$00FF
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _char_bitfield_bytes_L10
                LDA     #0
                BRL     _char_bitfield_bytes_L11
_char_bitfield_bytes_L10
                LDA     #1
_char_bitfield_bytes_L11
                CMP     #0
                BNE     *+5
                BRL     _char_bitfield_bytes_L9
                LDA     _fcc_img0
                TAX
                TXA
                ORA     #8
                STA     _fcc_img0
_char_bitfield_bytes_L9
                LDA     #17
                SEP     #$20
                MX      %10
                STA     1,S   ; fccstk d=0 b=1
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$F8FF
                STA     1,S   ; fccstk d=0 b=1
                LDA     #5
                AND     #$0007
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                AND     #$07FF
                STA     1,S   ; fccstk d=0 b=1
                LDA     #17
                AND     #$001F
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #2
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _char_bitfield_bytes_L15
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                TAX
                TXA
                CMP     #17
                BEQ     *+5
                BRL     _char_bitfield_bytes_L15
                LDA     #0
                BRL     _char_bitfield_bytes_L16
_char_bitfield_bytes_L15
                LDA     #1
_char_bitfield_bytes_L16
                CMP     #0
                BEQ     *+5
                BRL     _char_bitfield_bytes_L13
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
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #17
                ASL
                ASL
                ASL
                TAX
                TXA
                ORA     #5
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _char_bitfield_bytes_L13
                LDA     #0
                BRL     _char_bitfield_bytes_L14
_char_bitfield_bytes_L13
                LDA     #1
_char_bitfield_bytes_L14
                CMP     #0
                BNE     *+5
                BRL     _char_bitfield_bytes_L12
                LDA     _fcc_img0
                TAX
                TXA
                ORA     #16
                STA     _fcc_img0
_char_bitfield_bytes_L12
                LDA     _fcc_img0
                CMP     #0
                BNE     *+5
                BRL     _char_bitfield_bytes_L17
                LDA     _fcc_img0
                BRL     _char_bitfield_bytes_L18
_char_bitfield_bytes_L17
                LDA     #42
_char_bitfield_bytes_L18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
