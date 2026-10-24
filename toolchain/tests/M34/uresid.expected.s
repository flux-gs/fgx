                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from uresid.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT mk40k
mk40k            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mk40k_FRAMESIZE
                DO      mk40k_STKGUARD
                BCC     mk40k_stkovf
                CMP     _fcc_stkfloor
                BCS     mk40k_stkok
mk40k_stkovf       JMP     _fcc_stkoflow
                FIN
mk40k_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                TAY
                TSC
                CLC
                ADC     #mk40k_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mk40k_FRAMESIZE   EQU     0
mk40k_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     _uresid_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _uresid_FA0
                STA     gfp
                LDA     _fcc_fpr0+2
                STA     gfp+2
                SEP     #$20
                MX      %10
                LDA     _uresid_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _uresid_FA1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                LDA     gfp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gfp
                STA     _fcc_fpr0
                PHK
                PEA     _uresid_L3-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_uresid_L3
                TAX
                TXA
                LDX     #30000
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _uresid_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_uresid_L2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0
                PHK
                PEA     _uresid_L4-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_uresid_L4
                LDX     #10000
                STX     _fcc_tmp_b
                JSR     _fcc_divu16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL mk40k
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
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
                BNE     *+5
                BRL     _uresid_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_uresid_L5
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     gu
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gu
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     [_fcc_fpr0]
                TAX
                LDA     #2500
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divu16
                STA     [_fcc_fpr0]
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     gu
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$C350
                STA     gu
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shr16
                STA     [_fcc_fpr0]
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     gu
                TAY
                TYA
                SEC
                SBC     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
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
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 4
