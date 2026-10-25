                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_truth.c
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
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
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
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_truth_L0
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
_long_truth_L0
                LDA     lt_zero+2
                STA     _fcc_long_hi
                LDA     lt_zero
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
                BEQ     _long_truth_L1
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
_long_truth_L1
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                ORA     _fcc_long_hi
                BNE     _long_truth_L2
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
_long_truth_L2
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                ORA     _fcc_long_hi
                BEQ     _long_truth_L3
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
_long_truth_L3
                LDA     1,S   ; fccstk d=0 b=1
                BNE     _long_truth_L4
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
_long_truth_L4
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                ORA     _fcc_long_hi
                BEQ     _long_truth_L6
                LDA     #1
                BRA     _long_truth_L7
_long_truth_L6
                LDA     #0
_long_truth_L7
                TAX
                CMP     #1
                BEQ     _long_truth_L5
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
_long_truth_L5
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                ORA     _fcc_long_hi
                BEQ     _long_truth_L9
                LDA     lt_lo+2
                STA     _fcc_long_hi
                LDA     lt_lo
                ORA     _fcc_long_hi
                BNE     _long_truth_L8
_long_truth_L9
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
_long_truth_L8
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                ORA     _fcc_long_hi
                BNE     _long_truth_L10
                LDA     lt_zero+2
                STA     _fcc_long_hi
                LDA     lt_zero
                ORA     _fcc_long_hi
                BNE     _long_truth_L10
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
_long_truth_L10
                LDA     lt_zero+2
                STA     _fcc_long_hi
                LDA     lt_zero
                ORA     _fcc_long_hi
                BEQ     _long_truth_L11
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
_long_truth_L11
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     lt_zero+2
                STA     _fcc_long_hi
                LDA     lt_zero
                ORA     _fcc_long_hi
                BNE     _long_truth_L12
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
_long_truth_L12
                LDA     1,S   ; fccstk d=0 b=1
                BNE     _long_truth_L13
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
_long_truth_L13
                LDA     lt_zero+2
                STA     _fcc_long_hi
                LDA     lt_zero
                ORA     _fcc_long_hi
                BEQ     _long_truth_L15
                LDA     #1
                BRA     _long_truth_L16
_long_truth_L15
                LDA     #0
_long_truth_L16
                CMP     #0
                BEQ     _long_truth_L14
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
_long_truth_L14
                LDA     lt_zero+2
                STA     _fcc_long_hi
                LDA     lt_zero
                ORA     _fcc_long_hi
                BEQ     _long_truth_L17
                LDA     lt_lo+2
                STA     _fcc_long_hi
                LDA     lt_lo
                ORA     _fcc_long_hi
                BEQ     _long_truth_L17
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
_long_truth_L17
                LDA     lt_lo+2
                STA     _fcc_long_hi
                LDA     lt_lo
                ORA     _fcc_long_hi
                BNE     _long_truth_L18
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
_long_truth_L18
                LDA     lt_lo+2
                STA     _fcc_long_hi
                LDA     lt_lo
                ORA     _fcc_long_hi
                BEQ     _long_truth_L20
                LDA     #0
                BRA     _long_truth_L21
_long_truth_L20
                LDA     #1
_long_truth_L21
                CMP     #0
                BEQ     _long_truth_L19
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L19
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img0
_long_truth_L22
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                ORA     _fcc_long_hi
                BEQ     _long_truth_L23
                INC     _fcc_img0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                BRA     _long_truth_L22
_long_truth_L23
                LDA     _fcc_img0
                STA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #1
                BEQ     _long_truth_L24
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L24
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
_long_truth_L25
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                ORA     _fcc_long_hi
                BEQ     _long_truth_L27
                LDA     3,S   ; fccstk d=0 b=3
                CLC
                ADC     #1
                STA     3,S   ; fccstk d=0 b=3
_long_truth_L26
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                BRA     _long_truth_L25
_long_truth_L27
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #1
                BEQ     _long_truth_L28
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L28
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                LDA     lt_hi+2
                STA     _fcc_long_hi
                LDA     lt_hi
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
_long_truth_L29
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                CLC
                ADC     #1
                STA     3,S   ; fccstk d=0 b=3
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
_long_truth_L30
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                ORA     _fcc_long_hi
                BEQ     _long_truth_L31
                BRA     _long_truth_L29
_long_truth_L31
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #1
                BEQ     _long_truth_L32
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L32
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                LDA     lt_zero+2
                STA     _fcc_long_hi
                LDA     lt_zero
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
_long_truth_L33
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                ORA     _fcc_long_hi
                BEQ     _long_truth_L34
                LDA     3,S   ; fccstk d=0 b=3
                INC
                STA     3,S   ; fccstk d=0 b=3
                LDX     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _long_truth_L36
                EOR     #$8000
_long_truth_L36
                BPL     _long_truth_L35
                BRA     _long_truth_L34
_long_truth_L35
                BRA     _long_truth_L33
_long_truth_L34
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #0
                BEQ     _long_truth_L37
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L37
                LDA     lt_negzero+6
                STA     _fcc_q3
                LDA     lt_negzero+4
                STA     _fcc_q2
                LDA     lt_negzero+2
                STA     _fcc_long_hi
                LDA     lt_negzero
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
                BEQ     _long_truth_L38
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L38
                LDA     lt_negzero+6
                STA     _fcc_q3
                LDA     lt_negzero+4
                STA     _fcc_q2
                LDA     lt_negzero+2
                STA     _fcc_long_hi
                LDA     lt_negzero
                TAY
                LDA     _fcc_q3
                AND     #$7FFF
                ORA     _fcc_q2
                ORA     _fcc_long_hi
                STY     _fcc_tmp_b
                ORA     _fcc_tmp_b
                BEQ     _long_truth_L39
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L39
                LDA     lt_negzero+6
                STA     _fcc_q3
                LDA     lt_negzero+4
                STA     _fcc_q2
                LDA     lt_negzero+2
                STA     _fcc_long_hi
                LDA     lt_negzero
                TAY
                LDA     _fcc_q3
                AND     #$7FFF
                ORA     _fcc_q2
                ORA     _fcc_long_hi
                STY     _fcc_tmp_b
                ORA     _fcc_tmp_b
                BEQ     _long_truth_L40
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L40
                LDA     lt_fone+6
                STA     _fcc_q3
                LDA     lt_fone+4
                STA     _fcc_q2
                LDA     lt_fone+2
                STA     _fcc_long_hi
                LDA     lt_fone
                TAY
                LDA     _fcc_q3
                AND     #$7FFF
                ORA     _fcc_q2
                ORA     _fcc_long_hi
                STY     _fcc_tmp_b
                ORA     _fcc_tmp_b
                BNE     _long_truth_L41
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L41
                LDA     lt_fone+6
                STA     _fcc_q3
                LDA     lt_fone+4
                STA     _fcc_q2
                LDA     lt_fone+2
                STA     _fcc_long_hi
                LDA     lt_fone
                TAY
                LDA     _fcc_q3
                AND     #$7FFF
                ORA     _fcc_q2
                ORA     _fcc_long_hi
                STY     _fcc_tmp_b
                ORA     _fcc_tmp_b
                BEQ     _long_truth_L43
                LDA     #1
                BRA     _long_truth_L44
_long_truth_L43
                LDA     #0
_long_truth_L44
                TAX
                CMP     #1
                BEQ     _long_truth_L42
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L42
                FGX2_FARCALL lt_ret
                ORA     _fcc_long_hi
                BNE     _long_truth_L45
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L45
                FGX2_FARCALL lt_ret
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
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_truth_L46
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L46
                FGX2_FARCALL lt_ret
                ORA     _fcc_long_hi
                BEQ     _long_truth_L48
                LDA     #1
                BRA     _long_truth_L49
_long_truth_L48
                LDA     #0
_long_truth_L49
                TAX
                CMP     #1
                BEQ     _long_truth_L47
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_long_truth_L47
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_EXPORT lt_ret
lt_ret            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #lt_ret_FRAMESIZE
                DO      lt_ret_STKGUARD
                BCC     lt_ret_stkovf
                CMP     _fcc_stkfloor
                BCS     lt_ret_stkok
lt_ret_stkovf       JMP     _fcc_stkoflow
                FIN
lt_ret_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                TSC
                CLC
                ADC     #lt_ret_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
lt_ret_FRAMESIZE   EQU     0
lt_ret_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
