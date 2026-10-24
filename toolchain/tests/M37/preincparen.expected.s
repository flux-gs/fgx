                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from preincparen.c
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     #0
                STA     _fcc_img0
                LDA     #5
                STA     1,S   ; fccstk d=0 b=1
                LDA     #10
                STA     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_tmp_b
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                INC
                STA     [_fcc_ptr]
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #6
                BNE     _preincparen_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_preincparen_L0
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #7
                BNE     _preincparen_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_preincparen_L1
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                JSR     _fcc_long_add
                LDY     #2
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #4
                STA     [_fcc_fpr0],Y
                TXA
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000B
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
                BEQ     _preincparen_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_preincparen_L2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                STA     13,S   ; fccstk d=0 b=13
                TAX
                TXA
                CMP     #8
                BNE     _preincparen_L4
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #8
                BNE     _preincparen_L4
                LDA     #1
                BRA     _preincparen_L5
_preincparen_L4
                LDA     #0
_preincparen_L5
                CMP     #0
                BEQ     _preincparen_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #12
                STA     _fcc_img0
_preincparen_L3
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
