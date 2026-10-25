                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from int_const_ladder.c
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
                LDA     #65535
                STA     a
                TAY
                LDA     #0
                STA     a+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     b
                TAY
                LDA     _fcc_long_hi
                STA     b+2
                TYA
                LDA     #65535
                STA     c
                TAY
                LDA     #0
                STA     c+2
                TYA
                LDA     #32768
                STA     d
                TAY
                LDA     #0
                STA     d+2
                TYA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$7FFF
                STA     e
                TAY
                LDA     _fcc_long_hi
                STA     e+2
                TYA
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
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
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _int_const_ladder_L0
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_int_const_ladder_L0
                LDA     b+2
                STA     _fcc_long_hi
                LDA     b
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
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _int_const_ladder_L1
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_int_const_ladder_L1
                LDA     c+2
                STA     _fcc_long_hi
                LDA     c
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
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _int_const_ladder_L2
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_int_const_ladder_L2
                LDA     d+2
                STA     _fcc_long_hi
                LDA     d
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _int_const_ladder_L3
                LDA     _fcc_img0
                CLC
                ADC     #9
                STA     _fcc_img0
_int_const_ladder_L3
                LDA     e+2
                STA     _fcc_long_hi
                LDA     e
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$7FFF
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _int_const_ladder_L4
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #9
                STA     _fcc_img0
_int_const_ladder_L4
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
