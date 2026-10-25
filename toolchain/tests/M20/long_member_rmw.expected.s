                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_member_rmw.c
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
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_member_rmw_L0
                LDA     #10
                BRA     _long_member_rmw_L1
_long_member_rmw_L0
                LDA     #0
_long_member_rmw_L1
                STA     21,S   ; fccstk d=0 b=21
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
                LDA     [_fcc_fpr0],Y
                JSR     _fcc_long_add
                LDY     #4
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_member_rmw_L2
                LDA     #10
                BRA     _long_member_rmw_L3
_long_member_rmw_L2
                LDA     #0
_long_member_rmw_L3
                STA     23,S   ; fccstk d=0 b=23
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0014
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     _fcc_img0
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                LDX     #20
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_member_rmw_L4
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #21
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_member_rmw_L4
                LDA     #10
                BRA     _long_member_rmw_L5
_long_member_rmw_L4
                LDA     #0
_long_member_rmw_L5
                STA     25,S   ; fccstk d=0 b=25
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0029
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #4
                LDA     [_fcc_fpr0],Y
                JSR     _fcc_long_add
                LDY     #4
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                LDX     #42
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_member_rmw_L6
                LDA     #12
                BRA     _long_member_rmw_L7
_long_member_rmw_L6
                LDA     #0
_long_member_rmw_L7
                STA     27,S   ; fccstk d=0 b=27
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     23,S   ; fccstk d=0 b=23
                CLC
                ADC     25,S   ; fccstk d=0 b=25
                CLC
                ADC     27,S   ; fccstk d=0 b=27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
