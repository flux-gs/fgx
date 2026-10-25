                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from addr2delem.c
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
_addr2delem_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #3
                BVC     _addr2delem_L3
                EOR     #$8000
_addr2delem_L3
                BMI     *+5
                BRL     _addr2delem_L2
                LDA     #0
                STA     _fcc_img1
_addr2delem_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                SEC
                SBC     #4
                BVC     _addr2delem_L7
                EOR     #$8000
_addr2delem_L7
                BMI     *+5
                BRL     _addr2delem_L6
                LDA     #_addr2delem_i2
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                PHA
                LDA     _fcc_img1
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
                LDA     #256
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_img1
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_addr2delem_c2
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                PHA
                LDA     _fcc_img1
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
                LDA     #16
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_img1
                AND     #$00FF
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
                LDA     #_addr2delem_l2
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     _fcc_img1
                ASL
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
                LDA     #$7777
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
_addr2delem_L5
                INC     _fcc_img1
                BRL     _addr2delem_L4
_addr2delem_L6
_addr2delem_L1
                INC     _fcc_img0
                BRL     _addr2delem_L0
_addr2delem_L2
                LDA     #0
                STA     _fcc_img0
_addr2delem_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #2
                BVC     _addr2delem_L11
                EOR     #$8000
_addr2delem_L11
                BMI     *+5
                BRL     _addr2delem_L10
                LDA     #0
                STA     _fcc_img1
_addr2delem_L12
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                SEC
                SBC     #3
                BVC     _addr2delem_L15
                EOR     #$8000
_addr2delem_L15
                BMI     *+5
                BRL     _addr2delem_L14
                LDA     #0
                STA     _fcc_img2
_addr2delem_L16
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                TAX
                SEC
                SBC     #4
                BVC     _addr2delem_L19
                EOR     #$8000
_addr2delem_L19
                BPL     _addr2delem_L18
                LDA     #_addr2delem_i3
                PHA
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                ASL
                PHA
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                LDA     _fcc_img2
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
                LDA     #512
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     _fcc_img1
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     _fcc_img2
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
_addr2delem_L17
                INC     _fcc_img2
                BRA     _addr2delem_L16
_addr2delem_L18
_addr2delem_L13
                INC     _fcc_img1
                BRL     _addr2delem_L12
_addr2delem_L14
_addr2delem_L9
                INC     _fcc_img0
                BRL     _addr2delem_L8
_addr2delem_L10
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     #_addr2delem_i2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                TAX
                CMP     #272
                BEQ     _addr2delem_L20
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
_addr2delem_L20
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #273
                BEQ     _addr2delem_L21
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
_addr2delem_L21
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     #4
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #288
                BEQ     _addr2delem_L22
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
_addr2delem_L22
                LDA     #1
                ASL
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_i2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                TAX
                CMP     #274
                BEQ     _addr2delem_L23
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
_addr2delem_L23
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAX
                CMP     #275
                BEQ     _addr2delem_L24
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
_addr2delem_L24
                LDA     #2
                STA     19,S   ; fccstk d=0 b=19
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_i2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                TAX
                CMP     #289
                BEQ     _addr2delem_L25
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
_addr2delem_L25
                LDA     #0
                ASL
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_i2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                TAX
                CMP     #256
                BEQ     _addr2delem_L26
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
_addr2delem_L26
                LDA     #2
                ASL
                ASL
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_c2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img6
                LDA     _fcc_fpr0
                STA     _fcc_img5
                LDA     [_fcc_img5]
                AND     #$00FF
                PHA
                LDA     #27
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _addr2delem_L27
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
_addr2delem_L27
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _addr2delem_l2+2,X
                STA     _fcc_long_hi
                LDA:    _addr2delem_l2,X
                LDX     #18
                STX     _fcc_long_b_lo
                LDX     #30583
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _addr2delem_L28
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
_addr2delem_L28
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_l2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                LDX     #18
                STX     _fcc_long_b_lo
                LDX     #30583
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _addr2delem_L29
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
_addr2delem_L29
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                CLC
                ADC     #2
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                LDX     #19
                STX     _fcc_long_b_lo
                LDX     #30583
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _addr2delem_L30
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
_addr2delem_L30
                LDA     #2
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #_addr2delem_l2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                LDX     #32
                STX     _fcc_long_b_lo
                LDX     #30583
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _addr2delem_L31
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
_addr2delem_L31
                LDA     #1
                ASL
                INC
                ASL
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                LDA     #3
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_i3
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                TAX
                CMP     #595
                BEQ     _addr2delem_L32
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
_addr2delem_L32
                LDA     #1
                ASL
                INC
                ASL
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_i3
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                TAX
                CMP     #592
                BEQ     _addr2delem_L33
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
_addr2delem_L33
                LDA     #1
                ASL
                INC
                ASL
                ASL
                ASL
                CLC
                ADC     #_addr2delem_i3
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                TAX
                CMP     #576
                BEQ     _addr2delem_L34
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
_addr2delem_L34
                LDA     #2
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_i2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     [_fcc_img3]
                PHA
                LDA     #2
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _addr2delem_i2,X
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _addr2delem_L35
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
_addr2delem_L35
                LDA     #2
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     #_addr2delem_l2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _addr2delem_l2+2,X
                STA     _fcc_long_hi
                LDA:    _addr2delem_l2,X
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
                BEQ     _addr2delem_L36
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
_addr2delem_L36
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
