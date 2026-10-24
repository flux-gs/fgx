                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from paren_postincdec_value.c
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
                LDA     #5
                STA     _fcc_tmp_b
                INC
                STA     _fcc_img1
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #5
                BNE     _paren_postincdec_value_L1
                LDA     _fcc_img1
                TAX
                CMP     #6
                BNE     _paren_postincdec_value_L1
                LDA     #0
                BRA     _paren_postincdec_value_L2
_paren_postincdec_value_L1
                LDA     #1
_paren_postincdec_value_L2
                CMP     #0
                BEQ     _paren_postincdec_value_L0
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
_paren_postincdec_value_L0
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img1
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #6
                BNE     _paren_postincdec_value_L4
                LDA     _fcc_img1
                TAX
                CMP     #5
                BNE     _paren_postincdec_value_L4
                LDA     #0
                BRA     _paren_postincdec_value_L5
_paren_postincdec_value_L4
                LDA     #1
_paren_postincdec_value_L5
                CMP     #0
                BEQ     _paren_postincdec_value_L3
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
_paren_postincdec_value_L3
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                INC
                STA     _fcc_img1
                LDA     _fcc_tmp_b
                EOR     #$FFFF
                INC
                STA     _fcc_img0
                CMP     #$FFFB
                BNE     _paren_postincdec_value_L7
                LDA     _fcc_img1
                TAX
                CMP     #6
                BNE     _paren_postincdec_value_L7
                LDA     #0
                BRA     _paren_postincdec_value_L8
_paren_postincdec_value_L7
                LDA     #1
_paren_postincdec_value_L8
                CMP     #0
                BEQ     _paren_postincdec_value_L6
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
_paren_postincdec_value_L6
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img1
                LDA     _fcc_tmp_b
                BEQ     _paren_postincdec_value_L9
                LDA     #0
                BRA     _paren_postincdec_value_L10
_paren_postincdec_value_L9
                LDA     #1
_paren_postincdec_value_L10
                STA     _fcc_img0
                CMP     #0
                BNE     _paren_postincdec_value_L12
                LDA     _fcc_img1
                TAX
                CMP     #5
                BNE     _paren_postincdec_value_L12
                LDA     #0
                BRA     _paren_postincdec_value_L13
_paren_postincdec_value_L12
                LDA     #1
_paren_postincdec_value_L13
                CMP     #0
                BEQ     _paren_postincdec_value_L11
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
_paren_postincdec_value_L11
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                INC
                STA     _fcc_img1
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #5
                BNE     _paren_postincdec_value_L15
                LDA     _fcc_img1
                TAX
                CMP     #6
                BNE     _paren_postincdec_value_L15
                LDA     #0
                BRA     _paren_postincdec_value_L16
_paren_postincdec_value_L15
                LDA     #1
_paren_postincdec_value_L16
                CMP     #0
                BEQ     _paren_postincdec_value_L14
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
_paren_postincdec_value_L14
                LDA     #7
                STA     g
                STA     _fcc_tmp_b
                INC
                STA     g
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #7
                BNE     _paren_postincdec_value_L18
                LDA     g
                TAX
                CMP     #8
                BNE     _paren_postincdec_value_L18
                LDA     #0
                BRA     _paren_postincdec_value_L19
_paren_postincdec_value_L18
                LDA     #1
_paren_postincdec_value_L19
                CMP     #0
                BEQ     _paren_postincdec_value_L17
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
_paren_postincdec_value_L17
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img7
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img7
                STA     _fcc_long_hi
                LDA     _fcc_img6
                JSR     _fcc_long_add
                STA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img7
                TYA
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img7
                STA     _fcc_long_hi
                LDA     _fcc_img6
                JSR     _fcc_long_add
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                TYA
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _paren_postincdec_value_L21
                LDA     _fcc_img7
                STA     _fcc_long_hi
                LDA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1171
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _paren_postincdec_value_L21
                LDA     #0
                BRA     _paren_postincdec_value_L22
_paren_postincdec_value_L21
                LDA     #1
_paren_postincdec_value_L22
                CMP     #0
                BEQ     _paren_postincdec_value_L20
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
_paren_postincdec_value_L20
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     gl
                TAY
                LDA     _fcc_long_hi
                STA     gl+2
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                STA     _fcc_tmp_b
                LDA     _fcc_long_hi
                PHA
                LDA     _fcc_tmp_b
                JSR     _fcc_long_add
                STA     gl
                TAY
                LDA     _fcc_long_hi
                STA     gl+2
                TYA
                PLA
                STA     _fcc_long_hi
                LDA     _fcc_tmp_b
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                TYA
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _paren_postincdec_value_L24
                LDA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _paren_postincdec_value_L24
                LDA     #0
                BRA     _paren_postincdec_value_L25
_paren_postincdec_value_L24
                LDA     #1
_paren_postincdec_value_L25
                CMP     #0
                BEQ     _paren_postincdec_value_L23
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
_paren_postincdec_value_L23
                LDA     #buf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #10
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
                LDA     #buf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #20
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
                LDA     #buf
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #30
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
                LDA     #buf
                PHA
                LDA     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #40
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
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                STA     _fcc_img2
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_img0
                TAX
                CMP     #10
                BNE     _paren_postincdec_value_L27
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #buf
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_postincdec_value_L29
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_postincdec_value_L29
                LDA     #0
                BRA     _paren_postincdec_value_L30
_paren_postincdec_value_L29
                LDA     #1
_paren_postincdec_value_L30
                CMP     #0
                BNE     _paren_postincdec_value_L27
                LDA     #0
                BRA     _paren_postincdec_value_L28
_paren_postincdec_value_L27
                LDA     #1
_paren_postincdec_value_L28
                CMP     #0
                BEQ     _paren_postincdec_value_L26
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
_paren_postincdec_value_L26
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                STA     _fcc_img2
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_img0
                TAX
                CMP     #20
                BNE     _paren_postincdec_value_L32
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_postincdec_value_L34
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_postincdec_value_L34
                LDA     #0
                BRA     _paren_postincdec_value_L35
_paren_postincdec_value_L34
                LDA     #1
_paren_postincdec_value_L35
                CMP     #0
                BNE     _paren_postincdec_value_L32
                LDA     #0
                BRA     _paren_postincdec_value_L33
_paren_postincdec_value_L32
                LDA     #1
_paren_postincdec_value_L33
                CMP     #0
                BEQ     _paren_postincdec_value_L31
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L31
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                STA     _fcc_img2
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_img0
                TAX
                CMP     #10
                BNE     _paren_postincdec_value_L37
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #buf
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_postincdec_value_L39
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_postincdec_value_L39
                LDA     #0
                BRA     _paren_postincdec_value_L40
_paren_postincdec_value_L39
                LDA     #1
_paren_postincdec_value_L40
                CMP     #0
                BNE     _paren_postincdec_value_L37
                LDA     #0
                BRA     _paren_postincdec_value_L38
_paren_postincdec_value_L37
                LDA     #1
_paren_postincdec_value_L38
                CMP     #0
                BEQ     _paren_postincdec_value_L36
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L36
                LDA     #1
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
                STA     33,S   ; fccstk d=0 b=33
                LDA     _fcc_fpr0
                STA     31,S   ; fccstk d=0 b=31
                LDA     #buf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #255
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
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0+2
                LDA     31,S   ; fccstk d=0 b=31
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
                STA     _fcc_img0
                TAX
                CMP     #255
                BNE     _paren_postincdec_value_L44
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                BNE     _paren_postincdec_value_L44
                LDA     #0
                BRA     _paren_postincdec_value_L45
_paren_postincdec_value_L44
                LDA     #1
_paren_postincdec_value_L45
                CMP     #0
                BNE     _paren_postincdec_value_L42
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #30
                BNE     _paren_postincdec_value_L42
                LDA     #0
                BRA     _paren_postincdec_value_L43
_paren_postincdec_value_L42
                LDA     #1
_paren_postincdec_value_L43
                CMP     #0
                BEQ     _paren_postincdec_value_L41
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L41
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #30
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     37,S   ; fccstk d=0 b=37
                LDA     _fcc_fpr0
                STA     35,S   ; fccstk d=0 b=35
                STA     _fcc_ptr
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                STA     _fcc_img0
                BNE     _paren_postincdec_value_L49
                LDA     #1
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #255
                BNE     _paren_postincdec_value_L49
                LDA     #0
                BRA     _paren_postincdec_value_L50
_paren_postincdec_value_L49
                LDA     #1
_paren_postincdec_value_L50
                CMP     #0
                BNE     _paren_postincdec_value_L47
                LDA     #2
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #30
                BNE     _paren_postincdec_value_L47
                LDA     #0
                BRA     _paren_postincdec_value_L48
_paren_postincdec_value_L47
                LDA     #1
_paren_postincdec_value_L48
                CMP     #0
                BEQ     _paren_postincdec_value_L46
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L46
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #100
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #3
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #100
                BNE     _paren_postincdec_value_L54
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #101
                BNE     _paren_postincdec_value_L54
                LDA     #0
                BRA     _paren_postincdec_value_L55
_paren_postincdec_value_L54
                LDA     #1
_paren_postincdec_value_L55
                CMP     #0
                BNE     _paren_postincdec_value_L52
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #3
                BNE     _paren_postincdec_value_L52
                LDA     #0
                BRA     _paren_postincdec_value_L53
_paren_postincdec_value_L52
                LDA     #1
_paren_postincdec_value_L53
                CMP     #0
                BEQ     _paren_postincdec_value_L51
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L51
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                STA     21,S   ; fccstk d=0 b=21
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     25,S   ; fccstk d=0 b=25
                LDA     _fcc_fpr0
                STA     23,S   ; fccstk d=0 b=23
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img7
                TYA
                LDA     _fcc_img7
                STA     _fcc_long_hi
                LDA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _paren_postincdec_value_L57
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=0 b=19
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _paren_postincdec_value_L57
                LDA     #0
                BRA     _paren_postincdec_value_L58
_paren_postincdec_value_L57
                LDA     #1
_paren_postincdec_value_L58
                CMP     #0
                BEQ     _paren_postincdec_value_L56
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L56
                LDA     #9
                STA     39,S   ; fccstk d=0 b=39
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #38
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     47,S   ; fccstk d=0 b=47
                LDA     _fcc_fpr0
                STA     45,S   ; fccstk d=0 b=45
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #38
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #9
                BNE     _paren_postincdec_value_L60
                LDA     39,S   ; fccstk d=0 b=39
                TAX
                CMP     #10
                BNE     _paren_postincdec_value_L60
                LDA     #0
                BRA     _paren_postincdec_value_L61
_paren_postincdec_value_L60
                LDA     #1
_paren_postincdec_value_L61
                CMP     #0
                BEQ     _paren_postincdec_value_L59
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L59
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_ptr+2
                LDA     45,S   ; fccstk d=0 b=45
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                DEC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #10
                BNE     _paren_postincdec_value_L63
                LDA     39,S   ; fccstk d=0 b=39
                TAX
                CMP     #9
                BNE     _paren_postincdec_value_L63
                LDA     #0
                BRA     _paren_postincdec_value_L64
_paren_postincdec_value_L63
                LDA     #1
_paren_postincdec_value_L64
                CMP     #0
                BEQ     _paren_postincdec_value_L62
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L62
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
                STA     _fcc_tmp_b
                STA     41,S   ; fccstk d=0 b=41
                LDA     _fcc_ptr+2
                STA     43,S   ; fccstk d=0 b=43
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_ptr+2
                LDA     45,S   ; fccstk d=0 b=45
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_postincdec_value_L68
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_postincdec_value_L68
                LDA     #0
                BRA     _paren_postincdec_value_L69
_paren_postincdec_value_L68
                LDA     #1
_paren_postincdec_value_L69
                CMP     #0
                BNE     _paren_postincdec_value_L66
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_fpr0+2
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #buf
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _paren_postincdec_value_L70
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _paren_postincdec_value_L70
                LDA     #0
                BRA     _paren_postincdec_value_L71
_paren_postincdec_value_L70
                LDA     #1
_paren_postincdec_value_L71
                CMP     #0
                BNE     _paren_postincdec_value_L66
                LDA     #0
                BRA     _paren_postincdec_value_L67
_paren_postincdec_value_L66
                LDA     #1
_paren_postincdec_value_L67
                CMP     #0
                BEQ     _paren_postincdec_value_L65
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L65
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAX
                CMP     #1
                BNE     _paren_postincdec_value_L73
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #2
                BNE     _paren_postincdec_value_L73
                LDA     #0
                BRA     _paren_postincdec_value_L74
_paren_postincdec_value_L73
                LDA     #1
_paren_postincdec_value_L74
                CMP     #0
                BEQ     _paren_postincdec_value_L72
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L72
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                ASL
                STA     _fcc_img0
                TAX
                CMP     #4
                BNE     _paren_postincdec_value_L76
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #3
                BNE     _paren_postincdec_value_L76
                LDA     #0
                BRA     _paren_postincdec_value_L77
_paren_postincdec_value_L76
                LDA     #1
_paren_postincdec_value_L77
                CMP     #0
                BEQ     _paren_postincdec_value_L75
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L75
                LDA     #3
                INC
                STA     _fcc_img1
                STA     _fcc_img0
                TAX
                CMP     #4
                BNE     _paren_postincdec_value_L79
                LDA     _fcc_img1
                TAX
                CMP     #4
                BNE     _paren_postincdec_value_L79
                LDA     #0
                BRA     _paren_postincdec_value_L80
_paren_postincdec_value_L79
                LDA     #1
_paren_postincdec_value_L80
                CMP     #0
                BEQ     _paren_postincdec_value_L78
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_paren_postincdec_value_L78
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
main_FRAMESIZE   EQU     48
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
