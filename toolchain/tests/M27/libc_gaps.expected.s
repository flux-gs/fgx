                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libc_gaps.c
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libc_gaps_S0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #119
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strchr
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_libc_gaps_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL write
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _libc_gaps_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _libc_gaps_L4
                LDA     #0
                BRL     _libc_gaps_L5
_libc_gaps_L4
                LDA     #1
_libc_gaps_L5
                CMP     #0
                BNE     *+5
                BRL     _libc_gaps_L2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_ptr
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #119
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _libc_gaps_L2
                LDA     #1
                BRL     _libc_gaps_L3
_libc_gaps_L2
                LDA     #0
_libc_gaps_L3
                CMP     #0
                BNE     *+5
                BRL     _libc_gaps_L0
                LDA     #6
                BRL     _libc_gaps_L1
_libc_gaps_L0
                LDA     #0
_libc_gaps_L1
                STA     11,S   ; fccstk d=0 b=11
                CLC
                ADC     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #34
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 4
