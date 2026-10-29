                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from asg_unsigned.c
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
                LDA     up+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     up
                STA     _fcc_fpr0
                LDA     #61440
                STA     [_fcc_fpr0]
                STA     _fcc_img1
                TAY
                LDA     #0
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #61440
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _asg_unsigned_L0
                LDA     _fcc_img0
                CLC
                ADC     #14
                STA     _fcc_img0
_asg_unsigned_L0
                LDA     #1
                ASL
                CLC
                ADC     #ua
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #61440
                STA     [_fcc_fpr0]
                STA     _fcc_img1
                TAY
                LDA     #0
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #61440
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _asg_unsigned_L1
                LDA     _fcc_img0
                CLC
                ADC     #14
                STA     _fcc_img0
_asg_unsigned_L1
                LDA     #61440
                STA     st+0
                STA     _fcc_img1
                TAY
                LDA     #0
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #61440
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _asg_unsigned_L2
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #14
                STA     _fcc_img0
_asg_unsigned_L2
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
