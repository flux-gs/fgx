                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longincdec.c
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
                LDA     #3
                STA     _fcc_img1
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
_longincdec_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BEQ     _longincdec_L2
                INC     _fcc_img0
_longincdec_L1
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                JSR     _fcc_long_add
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                BRA     _longincdec_L0
_longincdec_L2
                LDA     _fcc_img0
                TAX
                CMP     #4
                BEQ     _longincdec_L3
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
_longincdec_L3
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _longincdec_L4
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
_longincdec_L4
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BEQ     _longincdec_L5
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
_longincdec_L5
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                JSR     _fcc_long_add
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
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
                BEQ     _longincdec_L6
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
_longincdec_L6
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                JSR     _fcc_long_add
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
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
                BEQ     _longincdec_L7
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
_longincdec_L7
                LDA     #0
                STA     _fcc_img1
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                JSR     _fcc_long_add
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                BEQ     _longincdec_L8
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
_longincdec_L8
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                JSR     _fcc_long_add
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
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
                BEQ     _longincdec_L9
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
_longincdec_L9
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
