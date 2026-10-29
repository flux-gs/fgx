                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrfieldlong.c
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
                LDA     #_arrfieldlong_ob
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #$1111
                STA     _fcc_long_hi
                LDA     #$2222
                STA     [_fcc_img1]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_img1],Y
                TXA
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     #$3333
                STA     _fcc_long_hi
                LDA     #$4444
                LDY     #32
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #34
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #0
                STA     _fcc_img0
_arrfieldlong_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #4
                BVC     _arrfieldlong_L3
                EOR     #$8000
_arrfieldlong_L3
                BPL     _arrfieldlong_L2
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #28
                STA     _fcc_fpr0
                LDA     _fcc_img0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
_arrfieldlong_L1
                INC     _fcc_img0
                BRA     _arrfieldlong_L0
_arrfieldlong_L2
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #$0A0B
                STA     _fcc_long_hi
                LDA     #$0C0D
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #3085
                STX     _fcc_long_b_lo
                LDX     #2571
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L4
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
_arrfieldlong_L4
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L5
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
_arrfieldlong_L5
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L6
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
_arrfieldlong_L6
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _arrfieldlong_L8
                LDX     #$FFFF
_arrfieldlong_L8
                STX     _fcc_long_hi
                TAX
                CMP     #2571
                BEQ     _arrfieldlong_L7
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
_arrfieldlong_L7
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                TAX
                CMP     #3085
                BEQ     _arrfieldlong_L9
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
_arrfieldlong_L9
                LDA     #3
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #$7E6D
                STA     _fcc_long_hi
                LDA     #$5C4B
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #3
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #23627
                STX     _fcc_long_b_lo
                LDX     #32365
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L10
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
_arrfieldlong_L10
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L11
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
_arrfieldlong_L11
                LDA     #4660
                STA     _fcc_img0
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img0
                JSR     _fcc_long_from_int
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #4660
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L12
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
_arrfieldlong_L12
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _arrfieldlong_L14
                LDX     #$FFFF
_arrfieldlong_L14
                STX     _fcc_long_hi
                CMP     #0
                BEQ     _arrfieldlong_L13
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
_arrfieldlong_L13
                LDA     #$FFFE
                STA     _fcc_img0
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img0
                JSR     _fcc_long_from_int
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #65534
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L15
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
_arrfieldlong_L15
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #17185
                STA     [_fcc_fpr0]
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #17185
                BEQ     _arrfieldlong_L16
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
_arrfieldlong_L16
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BNE     _arrfieldlong_L18
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     #3
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _arrfieldlong_L17
_arrfieldlong_L18
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
_arrfieldlong_L17
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #28
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #90
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #28
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #90
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _arrfieldlong_L19
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
_arrfieldlong_L19
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #28
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #0
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _arrfieldlong_L21
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #28
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     #0
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _arrfieldlong_L20
_arrfieldlong_L21
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
_arrfieldlong_L20
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #8738
                STX     _fcc_long_b_lo
                LDX     #4369
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L22
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
_arrfieldlong_L22
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDY     #34
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #32
                LDA     [_fcc_fpr0],Y
                LDX     #17476
                STX     _fcc_long_b_lo
                LDX     #13107
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L23
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
_arrfieldlong_L23
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #4660
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L24
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
_arrfieldlong_L24
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #3085
                STX     _fcc_long_b_lo
                LDX     #2571
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L25
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
_arrfieldlong_L25
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #65534
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L26
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
_arrfieldlong_L26
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #3
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #23627
                STX     _fcc_long_b_lo
                LDX     #32365
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _arrfieldlong_L27
                LDA     #69
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrfieldlong_L27
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
