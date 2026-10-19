                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from realloc_grow.c
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
                LDA     #16
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL malloc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _realloc_grow_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _realloc_grow_L1
                LDA     #1
                BRL     _realloc_grow_L2
_realloc_grow_L1
                LDA     #0
_realloc_grow_L2
                CMP     #0
                BNE     *+5
                BRL     _realloc_grow_L0
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
_realloc_grow_L0
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img0
_realloc_grow_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _realloc_grow_L6
                EOR     #$8000
_realloc_grow_L6
                BMI     *+5
                BRL     _realloc_grow_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
_realloc_grow_L4
                INC     _fcc_img0
                BRL     _realloc_grow_L3
_realloc_grow_L5
                LDA     _fcc_img0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #200
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL realloc
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _realloc_grow_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _realloc_grow_L8
                LDA     #1
                BRL     _realloc_grow_L9
_realloc_grow_L8
                LDA     #0
_realloc_grow_L9
                CMP     #0
                BNE     *+5
                BRL     _realloc_grow_L7
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
_realloc_grow_L7
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
_realloc_grow_L10
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _realloc_grow_L13
                EOR     #$8000
_realloc_grow_L13
                BMI     *+5
                BRL     _realloc_grow_L12
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _realloc_grow_L14
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
_realloc_grow_L14
_realloc_grow_L11
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
                BRL     _realloc_grow_L10
_realloc_grow_L12
                LDA     #16
                STA     5,S   ; fccstk d=0 b=5
_realloc_grow_L15
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #200
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _realloc_grow_L18
                EOR     #$8000
_realloc_grow_L18
                BMI     *+5
                BRL     _realloc_grow_L17
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                TAX
                LDA     #127
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
_realloc_grow_L16
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
                BRL     _realloc_grow_L15
_realloc_grow_L17
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
_realloc_grow_L19
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _realloc_grow_L22
                EOR     #$8000
_realloc_grow_L22
                BMI     *+5
                BRL     _realloc_grow_L21
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _realloc_grow_L23
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
_realloc_grow_L23
_realloc_grow_L20
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
                BRL     _realloc_grow_L19
_realloc_grow_L21
                LDA     #8
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL realloc
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _realloc_grow_L25
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _realloc_grow_L25
                LDA     #1
                BRL     _realloc_grow_L26
_realloc_grow_L25
                LDA     #0
_realloc_grow_L26
                CMP     #0
                BNE     *+5
                BRL     _realloc_grow_L24
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
_realloc_grow_L24
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
_realloc_grow_L27
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _realloc_grow_L30
                EOR     #$8000
_realloc_grow_L30
                BMI     *+5
                BRL     _realloc_grow_L29
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _realloc_grow_L31
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
_realloc_grow_L31
_realloc_grow_L28
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
                BRL     _realloc_grow_L27
_realloc_grow_L29
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL free
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #32
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL realloc
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _realloc_grow_L33
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _realloc_grow_L33
                LDA     #1
                BRL     _realloc_grow_L34
_realloc_grow_L33
                LDA     #0
_realloc_grow_L34
                CMP     #0
                BNE     *+5
                BRL     _realloc_grow_L32
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
_realloc_grow_L32
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #11
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #31
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #13
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                TAX
                LDA     #11
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _realloc_grow_L35
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
_realloc_grow_L35
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #31
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #255
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                TAX
                LDA     #13
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _realloc_grow_L36
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
_realloc_grow_L36
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL free
                TSC
                CLC
                ADC     #4
                TCS
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
