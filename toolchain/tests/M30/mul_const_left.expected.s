                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from mul_const_left.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _mul_const_left_iv
_mul_const_left_iv            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_mul_const_left_iv_FRAMESIZE
                DO      _mul_const_left_iv_STKGUARD
                BCC     _mul_const_left_iv_stkovf
                CMP     _fcc_stkfloor
                BCS     _mul_const_left_iv_stkok
_mul_const_left_iv_stkovf       JMP     _fcc_stkoflow
                FIN
_mul_const_left_iv_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_mul_const_left_iv_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mul_const_left_iv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mul_const_left_iv_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_mul_const_left_iv_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_const_left_iv_FRAMESIZE   EQU     0
_mul_const_left_iv_STKGUARD    EQU     0
                FGX2_EXPORT _mul_const_left_uv
_mul_const_left_uv            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_mul_const_left_uv_FRAMESIZE
                DO      _mul_const_left_uv_STKGUARD
                BCC     _mul_const_left_uv_stkovf
                CMP     _fcc_stkfloor
                BCS     _mul_const_left_uv_stkok
_mul_const_left_uv_stkovf       JMP     _fcc_stkoflow
                FIN
_mul_const_left_uv_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_mul_const_left_uv_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mul_const_left_uv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mul_const_left_uv_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_mul_const_left_uv_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_const_left_uv_FRAMESIZE   EQU     0
_mul_const_left_uv_STKGUARD    EQU     0
                FGX2_EXPORT _mul_const_left_lv
_mul_const_left_lv            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_mul_const_left_lv_FRAMESIZE
                DO      _mul_const_left_lv_STKGUARD
                BCC     _mul_const_left_lv_stkovf
                CMP     _fcc_stkfloor
                BCS     _mul_const_left_lv_stkok
_mul_const_left_lv_stkovf       JMP     _fcc_stkoflow
                FIN
_mul_const_left_lv_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_mul_const_left_lv_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_mul_const_left_lv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_mul_const_left_lv_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_mul_const_left_lv_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mul_const_left_lv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mul_const_left_lv_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_mul_const_left_lv_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_const_left_lv_FRAMESIZE   EQU     0
_mul_const_left_lv_STKGUARD    EQU     0
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
                LDA     #7
                PHA
                FGX2_FARCALL _mul_const_left_iv
                TAY
                PLA
                TYA
                STA     1,S   ; fccstk d=0 b=1
                LDA     #$FFFD
                PHA
                FGX2_FARCALL _mul_const_left_iv
                TAY
                PLA
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #2
                PHA
                FGX2_FARCALL _mul_const_left_iv
                TAY
                PLA
                TYA
                STA     5,S   ; fccstk d=0 b=5
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                PHA
                FGX2_FARCALL _mul_const_left_uv
                TAY
                PLA
                TYA
                STA     7,S   ; fccstk d=0 b=7
                LDA     #9
                PHA
                FGX2_FARCALL _mul_const_left_iv
                TAY
                PLA
                TYA
                AND     #$00FF
                STA     9,S   ; fccstk d=0 b=9
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_const_left_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                TYA
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                CMP     #28
                BEQ     _mul_const_left_L0
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
_mul_const_left_L0
                LDA     3,S   ; fccstk d=0 b=3
                ASL
                CMP     #$FFFA
                BEQ     _mul_const_left_L1
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
_mul_const_left_L1
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                CMP     #28
                BEQ     _mul_const_left_L2
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
_mul_const_left_L2
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                CMP     #28
                BEQ     _mul_const_left_L3
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
_mul_const_left_L3
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                CMP     #28
                BEQ     _mul_const_left_L4
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
_mul_const_left_L4
                LDA     #16
                TAX
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                CMP     #44
                BEQ     _mul_const_left_L5
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
_mul_const_left_L5
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                CMP     #28
                BEQ     _mul_const_left_L6
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
_mul_const_left_L6
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                TAX
                CMP     #70
                BEQ     _mul_const_left_L7
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
_mul_const_left_L7
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #12345
                STX     _fcc_tmp_b
                JSR     _fcc_mul16
                TAX
                CMP     #20879
                BEQ     _mul_const_left_L8
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
_mul_const_left_L8
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CMP     #$FFAC
                BEQ     _mul_const_left_L9
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
_mul_const_left_L9
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #65532
                STX     _fcc_tmp_b
                JSR     _fcc_mul16
                CMP     #$FFE4
                BEQ     _mul_const_left_L10
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
_mul_const_left_L10
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAX
                CMP     #54464
                BEQ     _mul_const_left_L11
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
_mul_const_left_L11
                LDA     9,S   ; fccstk d=0 b=9
                AND     #$00FF
                ASL
                ASL
                TAX
                CMP     #36
                BEQ     _mul_const_left_L12
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
_mul_const_left_L12
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                CMP     #28
                BEQ     _mul_const_left_L13
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
_mul_const_left_L13
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                LDX     #6784
                STX     _fcc_long_b_lo
                LDX     #6
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _mul_const_left_L14
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
_mul_const_left_L14
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                LDX     #13568
                STX     _fcc_long_b_lo
                LDX     #12
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _mul_const_left_L15
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
_mul_const_left_L15
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CMP     #$FFAC
                BEQ     _mul_const_left_L16
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
_mul_const_left_L16
                LDA     #_mul_const_left_row256
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #5
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #11
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_mul_const_left_row10
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                INC
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #12
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #2
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #5
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _mul_const_left_row256,X
                AND     #$00FF
                TAX
                CMP     #11
                BEQ     _mul_const_left_L17
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
_mul_const_left_L17
                LDA     #3
                ASL
                ASL
                CLC
                ADC     #3
                ASL
                PHA
                LDA     #7
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _mul_const_left_row10,X
                AND     #$00FF
                TAX
                CMP     #12
                BEQ     _mul_const_left_L18
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
_mul_const_left_L18
                LDA     #_mul_const_left_row256
                PHA
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #13
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_mul_const_left_row10
                PHA
                LDA     #1
                ASL
                ASL
                INC
                ASL
                PHA
                LDA     5,S   ; fccstk d=4 b=1
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #14
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #1
                PHA
                FGX2_FARCALL _mul_const_left_iv
                TAY
                PLA
                TYA
                STA     5,S   ; fccstk d=0 b=5
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                PHA
                LDA     #7
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _mul_const_left_row256,X
                AND     #$00FF
                TAX
                CMP     #13
                BEQ     _mul_const_left_L19
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
_mul_const_left_L19
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                LDA     #7
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    _mul_const_left_row10,X
                AND     #$00FF
                TAX
                CMP     #14
                BEQ     _mul_const_left_L20
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
_mul_const_left_L20
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
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 12
