                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptrstructassign.c
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
                LDA     #10
                TAX
                CMP     #10
                BEQ     _ptrstructassign_L0
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
_ptrstructassign_L0
                LDA     #8
                TAX
                CMP     #8
                BEQ     _ptrstructassign_L1
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
_ptrstructassign_L1
                LDA     #4660
                STA     g_src+0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf_f
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_src+2
                TAY
                LDA     _fcc_ptr+2
                STA     g_src+4
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_src+6
                TAY
                LDA     _fcc_ptr+2
                STA     g_src+8
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_src
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #44
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     #0
                STA     45,S   ; fccstk d=0 b=45
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     47,S   ; fccstk d=0 b=47
                LDA     _fcc_ptr+2
                STA     49,S   ; fccstk d=0 b=49
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_ptr+2
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     _fcc_img1
                STA     _fcc_fpr1+2
                LDA     _fcc_img0
                STA     _fcc_fpr1
                LDY     #8
_ptrstructassign_L2
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L2
                LDA     45,S   ; fccstk d=0 b=45
                TAX
                CMP     #4660
                BEQ     _ptrstructassign_L3
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
_ptrstructassign_L3
                LDA     49,S   ; fccstk d=0 b=49
                STA     _fcc_fpr0+2
                LDA     47,S   ; fccstk d=0 b=47
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_f
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L5
                LDA     #0
                BRA     _ptrstructassign_L6
_ptrstructassign_L5
                LDA     #1
_ptrstructassign_L6
                CMP     #0
                BEQ     _ptrstructassign_L4
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
_ptrstructassign_L4
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_fpr0+2
                LDA     51,S   ; fccstk d=0 b=51
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L8
                LDA     #0
                BRA     _ptrstructassign_L9
_ptrstructassign_L8
                LDA     #1
_ptrstructassign_L9
                CMP     #0
                BEQ     _ptrstructassign_L7
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L7
                LDA     #0
                STA     35,S   ; fccstk d=0 b=35
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     37,S   ; fccstk d=0 b=37
                LDA     _fcc_ptr+2
                STA     39,S   ; fccstk d=0 b=39
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
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
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #34
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #8
_ptrstructassign_L10
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L10
                LDA     35,S   ; fccstk d=0 b=35
                TAX
                CMP     #4660
                BEQ     _ptrstructassign_L11
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L11
                LDA     39,S   ; fccstk d=0 b=39
                STA     _fcc_fpr0+2
                LDA     37,S   ; fccstk d=0 b=37
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_f
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L13
                LDA     #0
                BRA     _ptrstructassign_L14
_ptrstructassign_L13
                LDA     #1
_ptrstructassign_L14
                CMP     #0
                BEQ     _ptrstructassign_L12
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L12
                LDA     43,S   ; fccstk d=0 b=43
                STA     _fcc_fpr0+2
                LDA     41,S   ; fccstk d=0 b=41
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L16
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L16
                LDA     #0
                BRA     _ptrstructassign_L17
_ptrstructassign_L16
                LDA     #1
_ptrstructassign_L17
                CMP     #0
                BEQ     _ptrstructassign_L15
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L15
                LDA     #273
                STA     gw_src+0
                LDA     #$2222
                STA     _fcc_long_hi
                LDA     #$3333
                STA     gw_src+2
                TAY
                LDA     _fcc_long_hi
                STA     gw_src+4
                TYA
                LDA     #1092
                STA     gw_src+6
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     15,S   ; fccstk d=0 b=15
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
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gw_src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #6
_ptrstructassign_L18
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L18
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #273
                BEQ     _ptrstructassign_L19
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L19
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                LDX     #13107
                STX     _fcc_long_b_lo
                LDX     #8738
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _ptrstructassign_L20
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L20
                LDA     15,S   ; fccstk d=0 b=15
                TAX
                CMP     #1092
                BEQ     _ptrstructassign_L21
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L21
                LDA     #22136
                STA     g_one_src+0
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img7
                LDA     _fcc_fpr0
                STA     _fcc_img6
                LDA     _fcc_img7
                STA     _fcc_fpr0+2
                LDA     _fcc_img6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_one_src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #0
_ptrstructassign_L22
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L22
                LDA     21,S   ; fccstk d=0 b=21
                TAX
                CMP     #22136
                BEQ     _ptrstructassign_L23
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L23
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #6
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #8
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #1911
                STA     g_dst+0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_dst+2
                TAY
                LDA     _fcc_ptr+2
                STA     g_dst+4
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf_f
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_dst+6
                TAY
                LDA     _fcc_ptr+2
                STA     g_dst+8
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     29,S   ; fccstk d=0 b=29
                LDA     _fcc_fpr0
                STA     27,S   ; fccstk d=0 b=27
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_src
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     33,S   ; fccstk d=0 b=33
                LDA     _fcc_fpr0
                STA     31,S   ; fccstk d=0 b=31
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_ptr+2
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #10
                STA     27,S   ; fccstk d=0 b=27
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_ptr+2
                LDA     31,S   ; fccstk d=0 b=31
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                CLC
                ADC     #10
                STA     31,S   ; fccstk d=0 b=31
                LDY     #8
_ptrstructassign_L24
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L24
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #4660
                BEQ     _ptrstructassign_L25
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L25
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_f
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L27
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L27
                LDA     #0
                BRA     _ptrstructassign_L28
_ptrstructassign_L27
                LDA     #1
_ptrstructassign_L28
                CMP     #0
                BEQ     _ptrstructassign_L26
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L26
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L30
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L30
                LDA     #0
                BRA     _ptrstructassign_L31
_ptrstructassign_L30
                LDA     #1
_ptrstructassign_L31
                CMP     #0
                BEQ     _ptrstructassign_L29
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L29
                LDA     29,S   ; fccstk d=0 b=29
                STA     _fcc_fpr0+2
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                CLC
                ADC     #10
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L33
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L33
                LDA     #0
                BRA     _ptrstructassign_L34
_ptrstructassign_L33
                LDA     #1
_ptrstructassign_L34
                CMP     #0
                BEQ     _ptrstructassign_L32
                LDA     #33
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L32
                LDA     33,S   ; fccstk d=0 b=33
                STA     _fcc_fpr0+2
                LDA     31,S   ; fccstk d=0 b=31
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #g_src
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
                BNE     _ptrstructassign_L36
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L36
                LDA     #0
                BRA     _ptrstructassign_L37
_ptrstructassign_L36
                LDA     #1
_ptrstructassign_L37
                CMP     #0
                BEQ     _ptrstructassign_L35
                LDA     #34
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L35
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #54
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #0
                BEQ     _ptrstructassign_L38
                LDA     #35
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L38
                LDA     #0
                STA     g_dst+0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_dst+2
                TAY
                LDA     _fcc_ptr+2
                STA     g_dst+4
                TYA
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_dst+6
                TAY
                LDA     _fcc_ptr+2
                STA     g_dst+8
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_dst
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_src
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #8
_ptrstructassign_L39
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L39
                LDA     g_dst+0
                TAX
                CMP     #4660
                BEQ     _ptrstructassign_L40
                LDA     #40
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L40
                LDA     g_dst+8
                STA     _fcc_fpr0+2
                LDA     g_dst+6
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L42
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L42
                LDA     #0
                BRA     _ptrstructassign_L43
_ptrstructassign_L42
                LDA     #1
_ptrstructassign_L43
                CMP     #0
                BEQ     _ptrstructassign_L41
                LDA     #41
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L41
                LDA     #0
                STA     45,S   ; fccstk d=0 b=45
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     47,S   ; fccstk d=0 b=47
                LDA     _fcc_ptr+2
                STA     49,S   ; fccstk d=0 b=49
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     51,S   ; fccstk d=0 b=51
                LDA     _fcc_ptr+2
                STA     53,S   ; fccstk d=0 b=53
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #44
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #34
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #8
_ptrstructassign_L44
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L44
                LDA     45,S   ; fccstk d=0 b=45
                TAX
                CMP     #4660
                BEQ     _ptrstructassign_L45
                LDA     #42
                TAX
                INC
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L45
                LDA     53,S   ; fccstk d=0 b=53
                STA     _fcc_fpr0+2
                LDA     51,S   ; fccstk d=0 b=51
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L47
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L47
                LDA     #0
                BRA     _ptrstructassign_L48
_ptrstructassign_L47
                LDA     #1
_ptrstructassign_L48
                CMP     #0
                BEQ     _ptrstructassign_L46
                LDA     #44
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L46
                LDA     #0
                STA     g_dst+0
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_dst+2
                TAY
                LDA     _fcc_ptr+2
                STA     g_dst+4
                TYA
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g_dst+6
                TAY
                LDA     _fcc_ptr+2
                STA     g_dst+8
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #34
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #g_dst
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr1+2
                LDA     _fcc_img0
                STA     _fcc_fpr1
                LDY     #8
_ptrstructassign_L49
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ptrstructassign_L49
                LDA     g_dst+0
                TAX
                CMP     #4660
                BEQ     _ptrstructassign_L50
                LDA     #45
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L50
                LDA     g_dst+8
                STA     _fcc_fpr0+2
                LDA     g_dst+6
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf_l
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ptrstructassign_L52
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ptrstructassign_L52
                LDA     #0
                BRA     _ptrstructassign_L53
_ptrstructassign_L52
                LDA     #1
_ptrstructassign_L53
                CMP     #0
                BEQ     _ptrstructassign_L51
                LDA     #46
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptrstructassign_L51
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
main_FRAMESIZE   EQU     74
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
