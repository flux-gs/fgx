                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from addrarrfieldidx.c
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
_addrarrfieldidx_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _addrarrfieldidx_L3
                EOR     #$8000
_addrarrfieldidx_L3
                BMI     *+5
                BRL     _addrarrfieldidx_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #4369
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #8738
                LDY     #18
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_img1
_addrarrfieldidx_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                TXA
                SEC
                SBC     #4
                BVC     _addrarrfieldidx_L7
                EOR     #$8000
_addrarrfieldidx_L7
                BMI     *+5
                BRL     _addrarrfieldidx_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
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
_addrarrfieldidx_L5
                INC     _fcc_img1
                BRL     _addrarrfieldidx_L4
_addrarrfieldidx_L6
_addrarrfieldidx_L1
                INC     _fcc_img0
                BRL     _addrarrfieldidx_L0
_addrarrfieldidx_L2
                LDA     #1
                STA     _fcc_img0
                LDA     #2
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #$4433
                STA     _fcc_long_hi
                LDA     #$2211
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4433
                STA     _fcc_long_hi
                LDA     #$2211
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
                BNE     *+5
                BRL     _addrarrfieldidx_L8
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
_addrarrfieldidx_L8
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                BNE     *+5
                BRL     _addrarrfieldidx_L9
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
_addrarrfieldidx_L9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                BNE     *+5
                BRL     _addrarrfieldidx_L10
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
_addrarrfieldidx_L10
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                BNE     *+5
                BRL     _addrarrfieldidx_L11
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
_addrarrfieldidx_L11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                INC
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                BNE     *+5
                BRL     _addrarrfieldidx_L12
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
_addrarrfieldidx_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #4369
                BNE     *+5
                BRL     _addrarrfieldidx_L13
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
_addrarrfieldidx_L13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #18
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #8738
                BNE     *+5
                BRL     _addrarrfieldidx_L14
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
_addrarrfieldidx_L14
                LDA     #0
                STA     _fcc_img0
                LDA     #0
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0A0B
                STA     _fcc_long_hi
                LDA     #$0C0D
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
                BNE     *+5
                BRL     _addrarrfieldidx_L15
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
_addrarrfieldidx_L15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #4369
                BNE     *+5
                BRL     _addrarrfieldidx_L16
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
_addrarrfieldidx_L16
                LDA     #2
                STA     _fcc_img0
                LDA     #3
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #$0E0F
                STA     _fcc_long_hi
                LDA     #$1011
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                INC
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0E0F
                STA     _fcc_long_hi
                LDA     #$1011
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
                BNE     *+5
                BRL     _addrarrfieldidx_L17
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
_addrarrfieldidx_L17
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                INC
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #18
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #8738
                BNE     *+5
                BRL     _addrarrfieldidx_L18
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
_addrarrfieldidx_L18
                LDA     #1
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #earr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #3
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr1+2
                LDA     9,S   ; fccstk d=0 b=9
                INC
                INC
                STA     _fcc_fpr1
                LDA     #3
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _addrarrfieldidx_L20
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _addrarrfieldidx_L20
                LDA     #0
                BRL     _addrarrfieldidx_L21
_addrarrfieldidx_L20
                LDA     #1
_addrarrfieldidx_L21
                CMP     #0
                BNE     *+5
                BRL     _addrarrfieldidx_L19
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
_addrarrfieldidx_L19
                LDA     #0
                STA     _fcc_img0
_addrarrfieldidx_L22
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #2
                BVC     _addrarrfieldidx_L25
                EOR     #$8000
_addrarrfieldidx_L25
                BMI     *+5
                BRL     _addrarrfieldidx_L24
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #13107
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #17476
                LDY     #14
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_img1
_addrarrfieldidx_L26
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _addrarrfieldidx_L29
                EOR     #$8000
_addrarrfieldidx_L29
                BMI     *+5
                BRL     _addrarrfieldidx_L28
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #0
                LDY     #2
                STA     [_fcc_fpr0],Y
_addrarrfieldidx_L27
                INC     _fcc_img1
                BRL     _addrarrfieldidx_L26
_addrarrfieldidx_L28
_addrarrfieldidx_L23
                INC     _fcc_img0
                BRL     _addrarrfieldidx_L22
_addrarrfieldidx_L24
                LDA     #1
                STA     _fcc_img0
                LDA     #2
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #21845
                STA     [_fcc_fpr0]
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #26214
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #21845
                BNE     *+5
                BRL     _addrarrfieldidx_L30
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
_addrarrfieldidx_L30
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #26214
                BNE     *+5
                BRL     _addrarrfieldidx_L31
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
_addrarrfieldidx_L31
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _addrarrfieldidx_L32
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
_addrarrfieldidx_L32
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _addrarrfieldidx_L33
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
_addrarrfieldidx_L33
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _addrarrfieldidx_L34
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
_addrarrfieldidx_L34
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #13107
                BNE     *+5
                BRL     _addrarrfieldidx_L35
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
_addrarrfieldidx_L35
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #harr
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #17476
                BNE     *+5
                BRL     _addrarrfieldidx_L36
                LDA     #36
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_addrarrfieldidx_L36
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
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
