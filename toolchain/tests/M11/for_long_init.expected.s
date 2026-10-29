                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from for_long_init.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                TSC
                SEC
                SBC     #main_FRAMESIZE-6
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
                STA     _fcc_img18
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                LDX     #1
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_add
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img18
                LDA     #0
                STA     _fcc_img16
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img17
                TYA
_for_long_init_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                STA     _fcc_long_hi
                LDA     _fcc_img16
                LDX     #6
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _for_long_init_L2
                LDA     _fcc_img18
                CLC
                ADC     #7
                STA     _fcc_img18
_for_long_init_L1
                LDA     _fcc_img17
                STA     _fcc_long_hi
                LDA     _fcc_img16
                LDX     #1
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_add
                STA     _fcc_img16
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img17
                TYA
                BRA     _for_long_init_L0
_for_long_init_L2
                LDA     _fcc_img18
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
                PLY
                PLY
                PLY
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-6
                TCS
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 3
