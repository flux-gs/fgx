                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_cast.c
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
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86CA
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
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                STA     5,S   ; fccstk d=0 b=5
                LDA     5,S   ; fccstk d=0 b=5
                JSR     _fcc_long_from_int
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
