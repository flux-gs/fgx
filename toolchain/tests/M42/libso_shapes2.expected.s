                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libso_shapes2.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT g
g            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #g_FRAMESIZE
                DO      g_STKGUARD
                BCC     g_stkovf
                CMP     _fcc_stkfloor
                BCS     g_stkok
g_stkovf       JMP     _fcc_stkoflow
                FIN
g_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #g_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
g_FRAMESIZE   EQU     0
g_STKGUARD    EQU     0
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
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _libso_shapes2_FA0+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libso_shapes2_FA0
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     #3
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #12
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #12
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #20
                INC
                INC
                STA     _fcc_fpr0
                LDA     #5
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     #1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #26
                CLC
                ADC     #6
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #4
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #38
                STA     _fcc_fpr0
                LDA     #16376
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #38
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #38
                STA     _fcc_fpr1
                LDY     #6
                LDA     [_fcc_fpr1],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr1],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr1],Y
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _fcc_dmul
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #46
                STA     _fcc_fpr0
                LDA     #5
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #46
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #46
                STA     _fcc_fpr1
                LDY     #6
                LDA     [_fcc_fpr1],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr1],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr1],Y
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
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
                FGX2_FARCALL _fcc_ll_mul
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #54
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #x
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #62
                STA     _fcc_fpr0
                LDA     #4
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #62
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                ORA     #3
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #63
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PHK
                PEA     _libso_shapes2_L21-1
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
_libso_shapes2_L21
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _libso_shapes2_L19
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_ptr
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _libso_shapes2_L19
                LDA     #1
                BRL     _libso_shapes2_L20
_libso_shapes2_L19
                LDA     #0
_libso_shapes2_L20
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L17
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #12
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1171
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
                BNE     *+5
                BRL     _libso_shapes2_L17
                LDA     #1
                BRL     _libso_shapes2_L18
_libso_shapes2_L17
                LDA     #0
_libso_shapes2_L18
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L15
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_ptr
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _libso_shapes2_L15
                LDA     #1
                BRL     _libso_shapes2_L16
_libso_shapes2_L15
                LDA     #0
_libso_shapes2_L16
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #26
                CLC
                ADC     #6
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _libso_shapes2_L13
                LDA     #1
                BRL     _libso_shapes2_L14
_libso_shapes2_L13
                LDA     #0
_libso_shapes2_L14
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #38
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                FGX2_FARCALL _fcc_dtol
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _libso_shapes2_L11
                LDA     #1
                BRL     _libso_shapes2_L12
_libso_shapes2_L11
                LDA     #0
_libso_shapes2_L12
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L9
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #46
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CMP     #15
                BEQ     *+5
                BRL     _libso_shapes2_L9
                LDA     #1
                BRL     _libso_shapes2_L10
_libso_shapes2_L9
                LDA     #0
_libso_shapes2_L10
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #54
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #11
                BEQ     *+5
                BRL     _libso_shapes2_L7
                LDA     #1
                BRL     _libso_shapes2_L8
_libso_shapes2_L7
                LDA     #0
_libso_shapes2_L8
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #62
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _libso_shapes2_L5
                LDA     #1
                BRL     _libso_shapes2_L6
_libso_shapes2_L5
                LDA     #0
_libso_shapes2_L6
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes2
                CLC
                ADC     #63
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L22
                LDA     #0
                BRL     _libso_shapes2_L23
_libso_shapes2_L22
                LDA     #1
_libso_shapes2_L23
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L3
                LDA     #1
                BRL     _libso_shapes2_L4
_libso_shapes2_L3
                LDA     #0
_libso_shapes2_L4
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes2_L1
                LDA     #42
                BRL     _libso_shapes2_L2
_libso_shapes2_L1
                LDA     #1
_libso_shapes2_L2
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
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 6
