                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_arith.c
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                LDX     #1000
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_mul
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #100
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_divs
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                LDX     #3
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_mul
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #2958
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
