                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_elem0.c
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
                ASL
                ASL
                CLC
                ADC     #c
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #$55E1
                STA     _fcc_long_hi
                LDA     #$191C
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #c
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #$55E1
                STA     _fcc_long_hi
                LDA     #$191C
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     x
                TAY
                LDA     _fcc_long_hi
                STA     x+2
                TYA
                SEP     #$20
                MX      %10
                LDA     x+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     x
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                LDX     #0
                STX     _fcc_long_hi
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #0
                STA     _fcc_img0
                LDA     c+6
                STA     _fcc_long_hi
                LDA     c+4
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptr_elem0_L0
                LDA     _fcc_img0
                CLC
                ADC     #20
                STA     _fcc_img0
_ptr_elem0_L0
                LDA     c+2
                STA     _fcc_long_hi
                LDA     c
                LDX     #6428
                STX     _fcc_long_b_lo
                LDX     #21985
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _ptr_elem0_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #22
                STA     _fcc_img0
_ptr_elem0_L1
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
