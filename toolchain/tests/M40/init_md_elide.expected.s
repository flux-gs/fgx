                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from init_md_elide.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _init_md_elide_sl
_init_md_elide_sl            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_init_md_elide_sl_FRAMESIZE
                DO      _init_md_elide_sl_STKGUARD
                BCC     _init_md_elide_sl_stkovf
                CMP     _fcc_stkfloor
                BCS     _init_md_elide_sl_stkok
_init_md_elide_sl_stkovf       JMP     _fcc_stkoflow
                FIN
_init_md_elide_sl_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                ASL
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_wday,X
                AND     #$00FF
                TAX
                TXA
                CMP     #83
                BEQ     *+5
                BRL     _init_md_elide_L3
                LDA     #0
                ASL
                CLC
                ADC     #0
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_wday,X
                AND     #$00FF
                TAX
                TXA
                CMP     #110
                BEQ     *+5
                BRL     _init_md_elide_L3
                LDA     #0
                BRL     _init_md_elide_L4
_init_md_elide_L3
                LDA     #1
_init_md_elide_L4
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L1
                LDA     #1
                ASL
                INC
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_wday,X
                AND     #$00FF
                TAX
                TXA
                CMP     #77
                BEQ     *+5
                BRL     _init_md_elide_L1
                LDA     #0
                BRL     _init_md_elide_L2
_init_md_elide_L1
                LDA     #1
_init_md_elide_L2
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L0
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #_init_md_elide_sl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L0
                LDA     #6
                ASL
                CLC
                ADC     #6
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_wday,X
                AND     #$00FF
                TAX
                TXA
                CMP     #83
                BEQ     *+5
                BRL     _init_md_elide_L8
                LDA     #6
                ASL
                CLC
                ADC     #6
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_wday,X
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _init_md_elide_L8
                LDA     #0
                BRL     _init_md_elide_L9
_init_md_elide_L8
                LDA     #1
_init_md_elide_L9
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L6
                LDA     #6
                ASL
                CLC
                ADC     #6
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_wday,X
                AND     #$00FF
                TAX
                TXA
                CMP     #116
                BEQ     *+5
                BRL     _init_md_elide_L6
                LDA     #0
                BRL     _init_md_elide_L7
_init_md_elide_L6
                LDA     #1
_init_md_elide_L7
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L5
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #_init_md_elide_sl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L5
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_dm,X
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _init_md_elide_L13
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_dm,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L13
                LDA     #0
                BRL     _init_md_elide_L14
_init_md_elide_L13
                LDA     #1
_init_md_elide_L14
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L11
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_dm,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L11
                LDA     #0
                BRL     _init_md_elide_L12
_init_md_elide_L11
                LDA     #1
_init_md_elide_L12
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L10
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #_init_md_elide_sl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L10
                LDA     #8
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _init_md_elide_L18
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_sz,X
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _init_md_elide_L18
                LDA     #0
                BRL     _init_md_elide_L19
_init_md_elide_L18
                LDA     #1
_init_md_elide_L19
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L16
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _init_md_elide_sl_sl_sz,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L16
                LDA     #0
                BRL     _init_md_elide_L17
_init_md_elide_L16
                LDA     #1
_init_md_elide_L17
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L15
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #_init_md_elide_sl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L15
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_init_md_elide_sl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_sl_FRAMESIZE   EQU     0
_init_md_elide_sl_STKGUARD    EQU     0
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
                CLC
                ADC     #0
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
                LDA:    y+2,X
                STA     _fcc_long_hi
                LDA:    y,X
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
                LDA     #16368
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
                BRL     _init_md_elide_L23
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    y+2,X
                STA     _fcc_long_hi
                LDA:    y,X
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
                LDA     #16404
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
                BRL     _init_md_elide_L23
                LDA     #0
                BRL     _init_md_elide_L24
_init_md_elide_L23
                LDA     #1
_init_md_elide_L24
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L21
                LDA     #1
                ASL
                INC
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
                LDA:    y+2,X
                STA     _fcc_long_hi
                LDA:    y,X
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
                BRL     _init_md_elide_L21
                LDA     #0
                BRL     _init_md_elide_L22
_init_md_elide_L21
                LDA     #1
_init_md_elide_L22
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L20
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
_init_md_elide_L20
                LDA     #2
                ASL
                INC
                INC
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    y+2,X
                STA     _fcc_long_hi
                LDA:    y,X
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
                LDA     #16412
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
                BRL     _init_md_elide_L28
                LDA     #3
                ASL
                CLC
                ADC     #3
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
                LDA:    y+2,X
                STA     _fcc_long_hi
                LDA:    y,X
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
                BRL     _init_md_elide_L28
                LDA     #0
                BRL     _init_md_elide_L29
_init_md_elide_L28
                LDA     #1
_init_md_elide_L29
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L26
                LDA     #3
                ASL
                CLC
                ADC     #3
                ASL
                ASL
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    y+2,X
                STA     _fcc_long_hi
                LDA:    y,X
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
                BRL     _init_md_elide_L26
                LDA     #0
                BRL     _init_md_elide_L27
_init_md_elide_L26
                LDA     #1
_init_md_elide_L27
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L25
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
_init_md_elide_L25
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    ml,X
                TAX
                TXA
                CMP     #28
                BEQ     *+5
                BRL     _init_md_elide_L33
                LDA     #1
                ASL
                INC
                ASL
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    ml,X
                TAX
                TXA
                CMP     #29
                BEQ     *+5
                BRL     _init_md_elide_L33
                LDA     #0
                BRL     _init_md_elide_L34
_init_md_elide_L33
                LDA     #1
_init_md_elide_L34
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L31
                LDA     #1
                ASL
                INC
                ASL
                ASL
                ASL
                PHA
                LDA     #11
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    ml,X
                TAX
                TXA
                CMP     #31
                BEQ     *+5
                BRL     _init_md_elide_L31
                LDA     #0
                BRL     _init_md_elide_L32
_init_md_elide_L31
                LDA     #1
_init_md_elide_L32
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L30
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
_init_md_elide_L30
                LDA     #0
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    mix,X
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _init_md_elide_L38
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    mix,X
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _init_md_elide_L38
                LDA     #0
                BRL     _init_md_elide_L39
_init_md_elide_L38
                LDA     #1
_init_md_elide_L39
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L36
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    mix,X
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _init_md_elide_L36
                LDA     #0
                BRL     _init_md_elide_L37
_init_md_elide_L36
                LDA     #1
_init_md_elide_L37
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L35
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
_init_md_elide_L35
                LDA     #2
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    mix,X
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _init_md_elide_L41
                LDA     #2
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    mix,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L41
                LDA     #0
                BRL     _init_md_elide_L42
_init_md_elide_L41
                LDA     #1
_init_md_elide_L42
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L40
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L40
                LDA     #12
                TAX
                TXA
                CMP     #12
                BNE     *+5
                BRL     _init_md_elide_L43
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L43
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    unsized,X
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _init_md_elide_L47
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    unsized,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L47
                LDA     #0
                BRL     _init_md_elide_L48
_init_md_elide_L47
                LDA     #1
_init_md_elide_L48
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L45
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    unsized,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L45
                LDA     #0
                BRL     _init_md_elide_L46
_init_md_elide_L45
                LDA     #1
_init_md_elide_L46
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L44
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L44
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
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    cube,X
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _init_md_elide_L50
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
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    cube,X
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _init_md_elide_L50
                LDA     #0
                BRL     _init_md_elide_L51
_init_md_elide_L50
                LDA     #1
_init_md_elide_L51
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L49
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L49
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
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    cube,X
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _init_md_elide_L53
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
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    cube,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L53
                LDA     #0
                BRL     _init_md_elide_L54
_init_md_elide_L53
                LDA     #1
_init_md_elide_L54
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L52
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L52
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
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    cube,X
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _init_md_elide_L56
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
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    cube,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L56
                LDA     #0
                BRL     _init_md_elide_L57
_init_md_elide_L56
                LDA     #1
_init_md_elide_L57
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L55
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L55
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
                LDA:    wide+2,X
                STA     _fcc_long_hi
                LDA:    wide,X
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
                BRL     _init_md_elide_L61
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
                LDA:    wide+2,X
                STA     _fcc_long_hi
                LDA:    wide,X
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
                BRL     _init_md_elide_L61
                LDA     #0
                BRL     _init_md_elide_L62
_init_md_elide_L61
                LDA     #1
_init_md_elide_L62
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L59
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
                LDA:    wide+2,X
                STA     _fcc_long_hi
                LDA:    wide,X
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
                BRL     _init_md_elide_L59
                LDA     #0
                BRL     _init_md_elide_L60
_init_md_elide_L59
                LDA     #1
_init_md_elide_L60
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L58
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L58
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    trail,X
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _init_md_elide_L64
                LDA     #1
                ASL
                ASL
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    trail,X
                CMP     #0
                BEQ     *+5
                BRL     _init_md_elide_L64
                LDA     #0
                BRL     _init_md_elide_L65
_init_md_elide_L64
                LDA     #1
_init_md_elide_L65
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L63
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L63
                FGX2_FARCALL _init_md_elide_sl
                STA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BNE     *+5
                BRL     _init_md_elide_L66
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_md_elide_L66
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 16
