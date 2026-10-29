                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ternary_ptrint.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ternary_ptrint_iv
_ternary_ptrint_iv            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ternary_ptrint_iv_FRAMESIZE
                DO      _ternary_ptrint_iv_STKGUARD
                BCC     _ternary_ptrint_iv_stkovf
                CMP     _fcc_stkfloor
                BCS     _ternary_ptrint_iv_stkok
_ternary_ptrint_iv_stkovf       JMP     _fcc_stkoflow
                FIN
_ternary_ptrint_iv_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_ternary_ptrint_iv_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ternary_ptrint_iv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ternary_ptrint_iv_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_ternary_ptrint_iv_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ternary_ptrint_iv_FRAMESIZE   EQU     0
_ternary_ptrint_iv_STKGUARD    EQU     0
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
                LDA     #5
                STA     11,S   ; fccstk d=0 b=11
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #120
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _ternary_ptrint_cmd
                LDA     _fcc_fpr0+2
                STA     _ternary_ptrint_cmd+2
                LDA     #_ternary_ptrint_vec
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #1
                PHA
                FGX2_FARCALL _ternary_ptrint_iv
                TAY
                PLA
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _ternary_ptrint_L0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L1
_ternary_ptrint_L0
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
_ternary_ptrint_L1
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BNE     *+5
                BRL     _ternary_ptrint_L2
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
_ternary_ptrint_L2
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CMP     #5
                BNE     *+5
                BRL     _ternary_ptrint_L3
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
_ternary_ptrint_L3
                LDA     #2
                PHA
                FGX2_FARCALL _ternary_ptrint_iv
                TAY
                PLA
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _ternary_ptrint_L4
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L5
_ternary_ptrint_L4
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
_ternary_ptrint_L5
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _ternary_ptrint_L6
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
_ternary_ptrint_L6
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _ternary_ptrint_L7
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
_ternary_ptrint_L7
                LDA     #5
                STA     11,S   ; fccstk d=0 b=11
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _ternary_ptrint_L8
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                BRL     _ternary_ptrint_L9
_ternary_ptrint_L8
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
_ternary_ptrint_L9
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _ternary_ptrint_L10
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
_ternary_ptrint_L10
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #2
                BNE     *+5
                BRL     _ternary_ptrint_L11
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                BRL     _ternary_ptrint_L12
_ternary_ptrint_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
_ternary_ptrint_L12
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BNE     *+5
                BRL     _ternary_ptrint_L13
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
_ternary_ptrint_L13
                LDA     #0
                PHA
                FGX2_FARCALL _ternary_ptrint_iv
                TAY
                PLA
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _ternary_ptrint_L14
                SEP     #$20
                MX      %10
                LDA     _ternary_ptrint_cmd+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _ternary_ptrint_cmd
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L15
_ternary_ptrint_L14
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ternary_ptrint_L18
                EOR     #$8000
_ternary_ptrint_L18
                BPL     *+5
                BRL     _ternary_ptrint_L16
                LDA     9,S   ; fccstk d=0 b=9
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    _ternary_ptrint_vec+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    _ternary_ptrint_vec,X
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L17
_ternary_ptrint_L16
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
_ternary_ptrint_L17
_ternary_ptrint_L15
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BNE     *+5
                BRL     _ternary_ptrint_L19
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
_ternary_ptrint_L19
                LDA     #1
                PHA
                FGX2_FARCALL _ternary_ptrint_iv
                TAY
                PLA
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _ternary_ptrint_L20
                SEP     #$20
                MX      %10
                LDA     _ternary_ptrint_cmd+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _ternary_ptrint_cmd
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L21
_ternary_ptrint_L20
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ternary_ptrint_L24
                EOR     #$8000
_ternary_ptrint_L24
                BPL     *+5
                BRL     _ternary_ptrint_L22
                LDA     9,S   ; fccstk d=0 b=9
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    _ternary_ptrint_vec+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    _ternary_ptrint_vec,X
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L23
_ternary_ptrint_L22
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
_ternary_ptrint_L23
_ternary_ptrint_L21
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BNE     *+5
                BRL     _ternary_ptrint_L25
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
_ternary_ptrint_L25
                LDA     #2
                PHA
                FGX2_FARCALL _ternary_ptrint_iv
                TAY
                PLA
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _ternary_ptrint_L26
                SEP     #$20
                MX      %10
                LDA     _ternary_ptrint_cmd+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _ternary_ptrint_cmd
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L27
_ternary_ptrint_L26
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ternary_ptrint_L30
                EOR     #$8000
_ternary_ptrint_L30
                BPL     *+5
                BRL     _ternary_ptrint_L28
                LDA     9,S   ; fccstk d=0 b=9
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    _ternary_ptrint_vec+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    _ternary_ptrint_vec,X
                STA     _fcc_fpr0
                BRL     _ternary_ptrint_L29
_ternary_ptrint_L28
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
_ternary_ptrint_L29
_ternary_ptrint_L27
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _ternary_ptrint_L31
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
_ternary_ptrint_L31
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
