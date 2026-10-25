                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from u_long.c
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
                LDA     #$8000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     #10
                JSR     _fcc_long_from_int
                STA     ub
                TAY
                LDA     _fcc_long_hi
                STA     ub+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_gtu
                CMP     #0
                BEQ     _u_long_L0
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
_u_long_L0
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #32767
                STX     _fcc_long_b_hi
                JSR     _fcc_long_geu
                CMP     #0
                BEQ     _u_long_L1
                LDA     _fcc_img0
                CLC
                ADC     #2
                STA     _fcc_img0
_u_long_L1
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_divu
                LDX     #52428
                STX     _fcc_long_b_lo
                LDX     #3276
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _u_long_L2
                LDA     _fcc_img0
                CLC
                ADC     #4
                STA     _fcc_img0
_u_long_L2
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     ub+2
                STA     _fcc_long_hi
                LDA     ub
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_modu
                LDX     #8
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _u_long_L3
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_u_long_L3
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     ua
                TAY
                LDA     _fcc_long_hi
                STA     ua+2
                TYA
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                LDX     #10
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_divu
                LDX     #39321
                STX     _fcc_long_b_lo
                LDX     #6553
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _u_long_L4
                LDA     _fcc_img0
                CLC
                ADC     #16
                STA     _fcc_img0
_u_long_L4
                LDA     ua+2
                STA     _fcc_long_hi
                LDA     ua
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #4095
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _u_long_L5
                LDA     _fcc_img0
                CLC
                ADC     #32
                STA     _fcc_img0
_u_long_L5
                LDA     _fcc_img0
                TAX
                CMP     #63
                BNE     _u_long_L6
                LDA     #42
                BRA     _u_long_L7
_u_long_L6
                LDA     _fcc_img0
_u_long_L7
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
