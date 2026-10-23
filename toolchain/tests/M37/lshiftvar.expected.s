                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from lshiftvar.c
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
                LDA     #9
                STA     _fcc_img1
_lshiftvar_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                TXA
                LDX     #12
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _lshiftvar_L3
                EOR     #$8000
_lshiftvar_L3
                BPL     *+5
                BRL     _lshiftvar_L2
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
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
                JSR     _fcc_long_shl
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                STA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img5
                TYA
                LDA     _fcc_img1
                TAX
                TXA
                CMP     #9
                BEQ     *+5
                BRL     _lshiftvar_L5
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$01FF
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
                BRL     _lshiftvar_L5
                LDA     #1
                BRL     _lshiftvar_L6
_lshiftvar_L5
                LDA     #0
_lshiftvar_L6
                CMP     #0
                BNE     *+5
                BRL     _lshiftvar_L4
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
_lshiftvar_L4
                LDA     _fcc_img1
                TAX
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _lshiftvar_L8
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$03FF
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
                BRL     _lshiftvar_L8
                LDA     #1
                BRL     _lshiftvar_L9
_lshiftvar_L8
                LDA     #0
_lshiftvar_L9
                CMP     #0
                BNE     *+5
                BRL     _lshiftvar_L7
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
_lshiftvar_L7
                LDA     _fcc_img1
                TAX
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _lshiftvar_L11
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$07FF
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
                BRL     _lshiftvar_L11
                LDA     #1
                BRL     _lshiftvar_L12
_lshiftvar_L11
                LDA     #0
_lshiftvar_L12
                CMP     #0
                BNE     *+5
                BRL     _lshiftvar_L10
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
_lshiftvar_L10
                LDA     _fcc_img1
                TAX
                TXA
                CMP     #12
                BEQ     *+5
                BRL     _lshiftvar_L14
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0FFF
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
                BRL     _lshiftvar_L14
                LDA     #1
                BRL     _lshiftvar_L15
_lshiftvar_L14
                LDA     #0
_lshiftvar_L15
                CMP     #0
                BNE     *+5
                BRL     _lshiftvar_L13
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
_lshiftvar_L13
_lshiftvar_L1
                INC     _fcc_img1
                BRL     _lshiftvar_L0
_lshiftvar_L2
                LDA     #$0006
                STA     _fcc_long_hi
                LDA     #$E065
                STA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img7
                TYA
                LDA     #0
                STA     _fcc_img0
_lshiftvar_L16
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                LDX     #7
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _lshiftvar_L19
                EOR     #$8000
_lshiftvar_L19
                BPL     *+5
                BRL     _lshiftvar_L18
                LDA     _fcc_img7
                STA     _fcc_long_hi
                LDA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #8
                SEC
                SBC     _fcc_img0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shr
                STA     _fcc_img12
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img13
                TYA
                LDA     #$0006
                STA     _fcc_long_hi
                LDA     #$E065
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #8
                SEC
                SBC     _fcc_img0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shr
                STA     17,S   ; fccstk d=0 b=17
                TAY
                LDA     _fcc_long_hi
                STA     19,S   ; fccstk d=0 b=19
                TYA
                LDA     #$0006
                STA     _fcc_long_hi
                LDA     #$E065
                STA     _fcc_img8
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img9
                TYA
                LDA     #8
                SEC
                SBC     _fcc_img0
                STA     _fcc_img2
_lshiftvar_L20
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img2
                LDA     _fcc_tmp_b
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _lshiftvar_L22
                EOR     #$8000
_lshiftvar_L22
                BMI     *+5
                BRL     _lshiftvar_L21
                LDA     _fcc_img9
                STA     _fcc_long_hi
                LDA     _fcc_img8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divs
                STA     _fcc_img8
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img9
                TYA
                BRL     _lshiftvar_L20
_lshiftvar_L21
                LDA     _fcc_img13
                STA     _fcc_long_hi
                LDA     _fcc_img12
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img9
                STA     _fcc_long_hi
                LDA     _fcc_img8
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
                BRL     _lshiftvar_L23
                LDA     #10
                CLC
                ADC     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_lshiftvar_L23
_lshiftvar_L17
                INC     _fcc_img0
                BRL     _lshiftvar_L16
_lshiftvar_L18
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0ABC
                STA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img7
                TYA
                LDA     #0
                STA     _fcc_img0
_lshiftvar_L24
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                LDX     #7
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _lshiftvar_L27
                EOR     #$8000
_lshiftvar_L27
                BPL     *+5
                BRL     _lshiftvar_L26
                LDA     _fcc_img7
                STA     _fcc_long_hi
                LDA     _fcc_img6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shl
                STA     _fcc_img14
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img15
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0ABC
                STA     _fcc_img10
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img11
                TYA
                LDA     _fcc_img0
                STA     _fcc_img3
_lshiftvar_L28
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img3
                STA     _fcc_tmp_b
                DEC
                STA     _fcc_img3
                LDA     _fcc_tmp_b
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _lshiftvar_L30
                EOR     #$8000
_lshiftvar_L30
                BMI     *+5
                BRL     _lshiftvar_L29
                LDA     _fcc_img11
                STA     _fcc_long_hi
                LDA     _fcc_img10
                ASL
                ROL     _fcc_long_hi
                STA     _fcc_img10
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img11
                TYA
                BRL     _lshiftvar_L28
_lshiftvar_L29
                LDA     _fcc_img15
                STA     _fcc_long_hi
                LDA     _fcc_img14
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img11
                STA     _fcc_long_hi
                LDA     _fcc_img10
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
                BRL     _lshiftvar_L31
                LDA     #20
                CLC
                ADC     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_lshiftvar_L31
_lshiftvar_L25
                INC     _fcc_img0
                BRL     _lshiftvar_L24
_lshiftvar_L26
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
main_FRAMESIZE   EQU     36
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
