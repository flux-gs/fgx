                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from init_md_wide.c
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
                ASL
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m+2,X
                STA     _fcc_long_hi
                LDA:    m,X
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
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L1
                LDA     #0
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m+2,X
                STA     _fcc_long_hi
                LDA:    m,X
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L1
                LDA     #0
                BRL     _init_md_wide_L2
_init_md_wide_L1
                LDA     #1
_init_md_wide_L2
                CMP     #0
                BNE     *+5
                BRL     _init_md_wide_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_wide_L0
                LDA     #1
                ASL
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m+2,X
                STA     _fcc_long_hi
                LDA:    m,X
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L4
                LDA     #1
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    m+2,X
                STA     _fcc_long_hi
                LDA:    m,X
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L4
                LDA     #0
                BRL     _init_md_wide_L5
_init_md_wide_L4
                LDA     #1
_init_md_wide_L5
                CMP     #0
                BNE     *+5
                BRL     _init_md_wide_L3
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_wide_L3
                LDA     #0
                ASL
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    fm+2,X
                STA     _fcc_long_hi
                LDA:    fm,X
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16376
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L7
                LDA     #0
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    fm+2,X
                STA     _fcc_long_hi
                LDA:    fm,X
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16384
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_q3
                EOR     #$8000
                STA     _fcc_q3
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L7
                LDA     #0
                BRL     _init_md_wide_L8
_init_md_wide_L7
                LDA     #1
_init_md_wide_L8
                CMP     #0
                BNE     *+5
                BRL     _init_md_wide_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_wide_L6
                LDA     #1
                ASL
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    fm+2,X
                STA     _fcc_long_hi
                LDA:    fm,X
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16392
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L10
                LDA     #1
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    fm+2,X
                STA     _fcc_long_hi
                LDA:    fm,X
                FGX2_FARCALL _fcc_dfromf
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BEQ     *+5
                BRL     _init_md_wide_L10
                LDA     #0
                BRL     _init_md_wide_L11
_init_md_wide_L10
                LDA     #1
_init_md_wide_L11
                CMP     #0
                BNE     *+5
                BRL     _init_md_wide_L9
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_wide_L9
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
