                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from for_long_init.c
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
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     9,S   ; fccstk d=0 b=9
                TYA
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_for_long_init_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #6
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _for_long_init_L2
                LDA     _fcc_img0
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_for_long_init_L1
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     7,S   ; fccstk d=0 b=7
                TAY
                LDA     _fcc_long_hi
                STA     9,S   ; fccstk d=0 b=9
                TYA
                BRL     _for_long_init_L0
_for_long_init_L2
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_for_long_init_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL printf
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 3
