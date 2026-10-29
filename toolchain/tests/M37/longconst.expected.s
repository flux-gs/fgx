                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longconst.c
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
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                LDX     #22136
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L0
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_longconst_L0
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L1
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_longconst_L1
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                LDX     #65534
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_add
                LDX     #22134
                STX     _fcc_long_b_lo
                LDX     #4660
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L2
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_longconst_L2
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                LDX     _fcc_long_hi
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
                CPX     #$8000
                BCC     _longconst_L4
                ORA     #$F000
_longconst_L4
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                LDX     #17767
                STX     _fcc_long_b_lo
                LDX     #291
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L3
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_longconst_L3
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                LDX     #4464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_divs
                LDX     #4363
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L5
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                LDX     #10
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_mods
                LDX     #6
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L5
                LDA     _fcc_img0
                CLC
                ADC     #5
                STA     _fcc_img0
_longconst_L5
                LDA     l+2
                STA     _fcc_long_hi
                LDA     l
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #32768
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_or
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #54905
                STX     _fcc_long_b_lo
                LDX     #4660
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L6
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #5
                STA     _fcc_img0
_longconst_L6
                LDA     #5
                STA     _fcc_img1
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #3
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_shl
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #40
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L7
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #65535
                STX     _fcc_long_b_hi
                JSR     _fcc_long_gts
                CMP     #0
                BEQ     _longconst_L7
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _longconst_L7
                LDA     _fcc_img0
                CLC
                ADC     #6
                STA     _fcc_img0
_longconst_L7
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_xor
                STA     _fcc_img1
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img2
                TYA
                LDA     _fcc_img2
                STA     _fcc_long_hi
                LDA     _fcc_img1
                LDX     #65495
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _longconst_L8
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #6
                STA     _fcc_img0
_longconst_L8
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
