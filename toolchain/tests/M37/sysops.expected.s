                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sysops.c
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
                STA     11,S   ; fccstk d=0 b=11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_sysops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL system
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                CMP     #0
                BNE     _sysops_L0
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CLC
                ADC     #11
                STA     11,S   ; fccstk d=0 b=11
_sysops_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_sysops_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL system
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                AND     #127
                CMP     #0
                BNE     _sysops_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                TAX
                TXA
                AND     #255
                TAX
                TXA
                CMP     #1
                BNE     _sysops_L2
                LDA     #1
                BRA     _sysops_L3
_sysops_L2
                LDA     #0
_sysops_L3
                CMP     #0
                BEQ     _sysops_L1
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CLC
                ADC     #11
                STA     11,S   ; fccstk d=0 b=11
_sysops_L1
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL time
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$6955
                STA     _fcc_long_hi
                LDA     #$B900
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_gts
                CMP     #0
                BEQ     _sysops_L4
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CLC
                ADC     #10
                STA     11,S   ; fccstk d=0 b=11
_sysops_L4
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL time
                TSC
                CLC
                ADC     #4
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BEQ     _sysops_L6
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #30
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
                BEQ     _sysops_L6
                LDA     #1
                BRA     _sysops_L7
_sysops_L6
                LDA     #0
_sysops_L7
                CMP     #0
                BEQ     _sysops_L5
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CLC
                ADC     #10
                STA     11,S   ; fccstk d=0 b=11
_sysops_L5
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
