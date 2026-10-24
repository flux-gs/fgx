                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libso_shapes.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fls
fls            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fls_FRAMESIZE
                DO      fls_STKGUARD
                BCC     fls_stkovf
                CMP     _fcc_stkfloor
                BCS     fls_stkok
fls_stkovf       JMP     _fcc_stkoflow
                FIN
fls_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #34
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #fls_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fls_FRAMESIZE   EQU     0
fls_STKGUARD    EQU     0
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
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #0
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
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CLC
                ADC     #4
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #0
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                STA     _fcc_fpr1
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                TAX
                TXA
                INC
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                FGX2_FARCALL sink
                TAY
                PLA
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #10
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
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #10
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #10
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                ASL
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #14
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
                JSR     _fcc_long_add
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
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #18
                CLC
                ADC     #7
                STA     _fcc_fpr0
                LDA     #122
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                FGX2_FARCALL fls
                FGX2_FARCALL fls
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #30
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #26
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
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #30
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_fpr0]
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #97
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #30
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
                LDA     #98
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _libso_shapes_L22
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _libso_shapes_L22
                LDA     #1
                BRL     _libso_shapes_L23
_libso_shapes_L22
                LDA     #0
_libso_shapes_L23
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L20
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #9
                BEQ     *+5
                BRL     _libso_shapes_L20
                LDA     #1
                BRL     _libso_shapes_L21
_libso_shapes_L20
                LDA     #0
_libso_shapes_L21
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L18
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #10
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _libso_shapes_L18
                LDA     #1
                BRL     _libso_shapes_L19
_libso_shapes_L18
                LDA     #0
_libso_shapes_L19
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #14
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
                BRL     _libso_shapes_L16
                LDA     #1
                BRL     _libso_shapes_L17
_libso_shapes_L16
                LDA     #0
_libso_shapes_L17
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L14
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #18
                CLC
                ADC     #7
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #122
                BEQ     *+5
                BRL     _libso_shapes_L14
                LDA     #1
                BRL     _libso_shapes_L15
_libso_shapes_L14
                LDA     #0
_libso_shapes_L15
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L12
                LDA     #8
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _libso_shapes_L12
                LDA     #1
                BRL     _libso_shapes_L13
_libso_shapes_L12
                LDA     #0
_libso_shapes_L13
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L10
                FGX2_FARCALL fls
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _libso_shapes_L10
                LDA     #1
                BRL     _libso_shapes_L11
_libso_shapes_L10
                LDA     #0
_libso_shapes_L11
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L8
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #0
                BEQ     *+5
                BRL     _libso_shapes_L8
                LDA     #1
                BRL     _libso_shapes_L9
_libso_shapes_L8
                LDA     #0
_libso_shapes_L9
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #26
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _libso_shapes_L6
                LDA     #1
                BRL     _libso_shapes_L7
_libso_shapes_L6
                LDA     #0
_libso_shapes_L7
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L4
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #26
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #98
                BEQ     *+5
                BRL     _libso_shapes_L4
                LDA     #1
                BRL     _libso_shapes_L5
_libso_shapes_L4
                LDA     #0
_libso_shapes_L5
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #30
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes
                CLC
                ADC     #26
                STA     _fcc_fpr1
                LDA     #1
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _libso_shapes_L24
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _libso_shapes_L24
                LDA     #1
                BRL     _libso_shapes_L25
_libso_shapes_L24
                LDA     #0
_libso_shapes_L25
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L2
                LDA     #1
                BRL     _libso_shapes_L3
_libso_shapes_L2
                LDA     #0
_libso_shapes_L3
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes_L0
                LDA     #42
                BRL     _libso_shapes_L1
_libso_shapes_L0
                LDA     #1
_libso_shapes_L1
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
                FGX2_EXPORT sink
sink            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sink_FRAMESIZE
                DO      sink_STKGUARD
                BCC     sink_stkovf
                CMP     _fcc_stkfloor
                BCS     sink_stkok
sink_stkovf       JMP     _fcc_stkoflow
                FIN
sink_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sink_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sink_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sink_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #sink_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sink_FRAMESIZE   EQU     0
sink_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
