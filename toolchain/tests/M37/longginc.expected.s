                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longginc.c
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
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     fe+2
                STA     _fcc_long_hi
                LDA     fe
                STA     _fcc_tmp_b
                LDA     _fcc_long_hi
                PHA
                LDA     _fcc_tmp_b
                JSR     _fcc_long_add
                STA     fe
                TAY
                LDA     _fcc_long_hi
                STA     fe+2
                TYA
                PLA
                STA     _fcc_long_hi
                LDA     _fcc_tmp_b
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     ct+2
                STA     _fcc_long_hi
                LDA     ct
                CLC
                ADC     #1
                STA     ct
                LDA     _fcc_long_hi
                ADC     #0
                STA     ct+2
                LDA     fe+2
                STA     _fcc_long_hi
                LDA     fe
                CLC
                ADC     #1
                STA     fe
                LDA     _fcc_long_hi
                ADC     #0
                STA     fe+2
                STA     _fcc_long_hi
                LDA     fe
                SEC
                SBC     #1
                STA     fe
                LDA     _fcc_long_hi
                SBC     #0
                STA     fe+2
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #40
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longginc_L0
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
_longginc_L0
                LDA     fe+2
                STA     _fcc_long_hi
                LDA     fe
                LDX     #41
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longginc_L1
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
_longginc_L1
                LDA     ct+2
                STA     _fcc_long_hi
                LDA     ct
                LDX     #1
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _longginc_L2
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
_longginc_L2
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #40
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     fe+2
                STA     _fcc_long_hi
                LDA     fe
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
                LDA     ct+2
                STA     _fcc_long_hi
                LDA     ct
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
