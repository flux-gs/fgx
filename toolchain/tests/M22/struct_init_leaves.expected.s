                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_init_leaves.c
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
                LDA     _struct_init_leaves_zru+2
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+0
                LDX     #1
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L0
                LDA     _struct_init_leaves_zru+6
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+4
                LDX     #2
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L0
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_struct_init_leaves_L0
                LDA     _struct_init_leaves_zru+10
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+8
                LDX     #3
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L1
                LDA     _struct_init_leaves_zru+14
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+12
                LDX     #4
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L1
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_struct_init_leaves_L1
                LDA     _struct_init_leaves_zru+18
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_zru+16
                LDX     #5
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L2
                LDA     _struct_init_leaves_zru+20
                CMP     #6
                BNE     _struct_init_leaves_L2
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_struct_init_leaves_L2
                LDA     _struct_init_leaves_part+2
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+0
                LDX     #7
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L3
                LDA     _struct_init_leaves_part+6
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+4
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L3
                LDA     _fcc_img0
                CLC
                ADC     #8
                STA     _fcc_img0
_struct_init_leaves_L3
                LDA     _struct_init_leaves_part+10
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+8
                LDX     #8
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L4
                LDA     _struct_init_leaves_part+14
                STA     _fcc_long_hi
                LDA     _struct_init_leaves_part+12
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _struct_init_leaves_L4
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #8
                STA     _fcc_img0
_struct_init_leaves_L4
                LDA     _struct_init_leaves_nulv+2
                STA     _fcc_fpr0+2
                LDA     _struct_init_leaves_nulv+0
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nv
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _struct_init_leaves_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _struct_init_leaves_L6
                LDA     #1
                BRA     _struct_init_leaves_L7
_struct_init_leaves_L6
                LDA     #0
_struct_init_leaves_L7
                CMP     #0
                BEQ     _struct_init_leaves_L5
                LDA     _struct_init_leaves_nulv+6
                STA     _fcc_fpr0+2
                LDA     _struct_init_leaves_nulv+4
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nm
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _struct_init_leaves_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _struct_init_leaves_L8
                LDA     #1
                BRA     _struct_init_leaves_L9
_struct_init_leaves_L8
                LDA     #0
_struct_init_leaves_L9
                CMP     #0
                BEQ     _struct_init_leaves_L5
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #4
                STA     _fcc_img0
_struct_init_leaves_L5
                LDA     _struct_init_leaves_nulv+10
                STA     _fcc_fpr0+2
                LDA     _struct_init_leaves_nulv+8
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _struct_init_leaves_L11
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _struct_init_leaves_L11
                LDA     #1
                BRA     _struct_init_leaves_L12
_struct_init_leaves_L11
                LDA     #0
_struct_init_leaves_L12
                CMP     #0
                BEQ     _struct_init_leaves_L10
                LDA     _struct_init_leaves_nulv+14
                STA     _fcc_fpr0+2
                LDA     _struct_init_leaves_nulv+12
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _struct_init_leaves_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _struct_init_leaves_L13
                LDA     #1
                BRA     _struct_init_leaves_L14
_struct_init_leaves_L13
                LDA     #0
_struct_init_leaves_L14
                CMP     #0
                BEQ     _struct_init_leaves_L10
                LDA     _struct_init_leaves_nulv+18
                STA     _fcc_fpr0+2
                LDA     _struct_init_leaves_nulv+16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _struct_init_leaves_L15
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _struct_init_leaves_L15
                LDA     #1
                BRA     _struct_init_leaves_L16
_struct_init_leaves_L15
                LDA     #0
_struct_init_leaves_L16
                CMP     #0
                BEQ     _struct_init_leaves_L10
                LDA     _struct_init_leaves_nulv+20
                BNE     _struct_init_leaves_L10
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #4
                STA     _fcc_img0
_struct_init_leaves_L10
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
