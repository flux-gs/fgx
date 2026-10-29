                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from uconst_long.c
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
                LDA     a+2
                STA     _fcc_long_hi
                LDA     a
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _uconst_long_L0
                LDA     _fcc_img0
                CLC
                ADC     #20
                STA     _fcc_img0
_uconst_long_L0
                LDA     #0
                ASL
                ASL
                TAX
                LDA:    b+2,X
                STA     _fcc_long_hi
                LDA:    b,X
                LDX     #61440
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _uconst_long_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #22
                STA     _fcc_img0
_uconst_long_L1
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
