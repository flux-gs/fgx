                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pp_adv4.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT take2
take2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #take2_FRAMESIZE
                DO      take2_STKGUARD
                BCC     take2_stkovf
                CMP     _fcc_stkfloor
                BCS     take2_stkok
take2_stkovf       JMP     _fcc_stkoflow
                FIN
take2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+take2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+take2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+take2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+take2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+take2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+take2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #take2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
take2_FRAMESIZE   EQU     0
take2_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
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
                TAX
                LDA     #4
                TAY
                TYA
                INC
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                LDA     #4
                TAY
                TYA
                INC
                TAY
                TYA
                INC
                INC
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     #3
                STA     _fcc_img16
_pp_adv4_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _pp_adv4_L2
                EOR     #$8000
_pp_adv4_L2
                BPL     _pp_adv4_L1
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #1
                STA     _fcc_img16
                BRA     _pp_adv4_L0
_pp_adv4_L1
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     _fcc_img16
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #4454
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                LDX     #10
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _pp_adv4_L3
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_pp_adv4_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pp_adv4_S0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #9
                BNE     _pp_adv4_L4
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #5
                STA     1,S   ; fccstk d=0 b=1
_pp_adv4_L4
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #2
                TAX
                CLC
                ADC     #3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #3
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL take2
                TAY
                PLA
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                INC
                INC
                STA     1,S   ; fccstk d=0 b=1
                TAX
                INC
                INC
                STA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
