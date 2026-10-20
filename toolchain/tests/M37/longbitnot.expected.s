                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longbitnot.c
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
                LDA     #$0080
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_not
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FF7F
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
                BNE     *+5
                BRL     _longbitnot_L0
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
_longbitnot_L0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_not
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFE
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
                BRL     _longbitnot_L1
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
_longbitnot_L1
                LDA     #$0080
                STA     _fcc_long_hi
                LDA     #$0010
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0080
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_not
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0010
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
                BRL     _longbitnot_L2
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
_longbitnot_L2
                LDA     #$0080
                STA     _fcc_long_hi
                LDA     #$0010
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0080
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_not
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0010
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
                BRL     _longbitnot_L3
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
_longbitnot_L3
                LDA     #$0080
                STA     _fcc_long_hi
                LDA     #$0010
                STA     lo
                TAY
                LDA     _fcc_long_hi
                STA     lo+2
                TYA
                LDA     lo+2
                STA     _fcc_long_hi
                LDA     lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0010
                JSR     _fcc_long_not
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     lo
                TAY
                LDA     _fcc_long_hi
                STA     lo+2
                TYA
                LDA     lo+2
                STA     _fcc_long_hi
                LDA     lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0080
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
                BRL     _longbitnot_L4
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
_longbitnot_L4
                LDA     #$0080
                STA     _fcc_long_hi
                LDA     #$0000
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                JSR     _fcc_long_not
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FF7F
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
                BNE     *+5
                BRL     _longbitnot_L5
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
_longbitnot_L5
                LDA     #$0F0F
                STA     _fcc_long_hi
                LDA     #$0F0F
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                JSR     _fcc_long_not
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$F0F0
                STA     _fcc_long_hi
                LDA     #$F0F0
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
                BRL     _longbitnot_L6
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
_longbitnot_L6
                LDA     #$003C
                STA     _fcc_long_hi
                LDA     #$00FF
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$003C
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_not
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     hv
                TAY
                LDA     _fcc_long_hi
                STA     hv+2
                TYA
                LDA     hv+2
                STA     _fcc_long_hi
                LDA     hv
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$00FF
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
                BRL     _longbitnot_L7
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
_longbitnot_L7
                LDA     #240
                STA     sh
                PHA
                LDA     #15
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     sh
                TAX
                LDA     #240
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _longbitnot_L8
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
_longbitnot_L8
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
