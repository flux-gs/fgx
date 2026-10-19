                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libso_calls.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _libso_calls_helper
_libso_calls_helper            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_libso_calls_helper_FRAMESIZE
                DO      _libso_calls_helper_STKGUARD
                BCC     _libso_calls_helper_stkovf
                CMP     _fcc_stkfloor
                BCS     _libso_calls_helper_stkok
_libso_calls_helper_stkovf       JMP     _fcc_stkoflow
                FIN
_libso_calls_helper_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_libso_calls_helper_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_libso_calls_helper_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_libso_calls_helper_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_libso_calls_helper_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_libso_calls_helper_FRAMESIZE   EQU     0
_libso_calls_helper_STKGUARD    EQU     0
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
                LDA     #3
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #5
                JSR     _fcc_long_from_int
                LDX     #0
                BIT     _fcc_long_hi
                BPL     *+5
                LDX     #$FFFF
                STX     _fcc_q2
                STX     _fcc_q3
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_calls
                CLC
                ADC     #0
                STA     _fcc_fpr0
                TAX
                FGX2_FARCALL setjmp
                CMP     #0
                BNE     *+5
                BRL     _libso_calls_L0
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
_libso_calls_L0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     23,S   ; fccstk d=8 b=15
                STA     _fcc_q3
                LDA     21,S   ; fccstk d=8 b=13
                STA     _fcc_q2
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_long_hi
                LDA     17,S   ; fccstk d=8 b=9
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
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL _libso_calls_helper
                TAY
                PLA
                TYA
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _libso_calls_L1
                LDA     #42
                BRL     _libso_calls_L2
_libso_calls_L1
                FGX2_FARCALL ext
_libso_calls_L2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_EXPORT ext
ext            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ext_FRAMESIZE
                DO      ext_STKGUARD
                BCC     ext_stkovf
                CMP     _fcc_stkfloor
                BCS     ext_stkok
ext_stkovf       JMP     _fcc_stkoflow
                FIN
ext_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #ext_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ext_FRAMESIZE   EQU     0
ext_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
