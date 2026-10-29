                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptrinit_const.c
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
                SEP     #$20
                MX      %10
                LDA     shr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     shr
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                SEP     #$20
                MX      %10
                LDA     shr4+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     shr4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img4
                TYA
                SEP     #$20
                MX      %10
                LDA     nul+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     nul
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     _fcc_img5
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img6
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #255
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                LDX     #8192
                STX     _fcc_long_b_lo
                LDX     #225
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptrinit_const_L0
                LDA     _fcc_img0
                CLC
                ADC     #14
                STA     _fcc_img0
_ptrinit_const_L0
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #255
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                LDX     #8196
                STX     _fcc_long_b_lo
                LDX     #225
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptrinit_const_L1
                LDA     _fcc_img0
                CLC
                ADC     #14
                STA     _fcc_img0
_ptrinit_const_L1
                LDA     _fcc_img6
                STA     _fcc_long_hi
                LDA     _fcc_img5
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptrinit_const_L2
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_ptrinit_const_L2
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
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
