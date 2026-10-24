                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from libso_shapes3.c
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
                LDA     #5
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
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
_libso_shapes3_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _libso_shapes3_L3
                EOR     #$8000
_libso_shapes3_L3
                BMI     *+5
                BRL     _libso_shapes3_L2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
_libso_shapes3_L1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                CLC
                ADC     #1
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                BRL     _libso_shapes3_L0
_libso_shapes3_L2
_libso_shapes3_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                SEC
                SBC     #5
                BVC     _libso_shapes3_L7
                EOR     #$8000
_libso_shapes3_L7
                BMI     *+5
                BRL     _libso_shapes3_L6
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_libso_shapes3_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                CLC
                ADC     #1
                STA     [_fcc_fpr0]
                LDA     _fcc_tmp_b
                BRL     _libso_shapes3_L4
_libso_shapes3_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                INC
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     #9
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
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
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #6
                CLC
                ADC     #4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _libso_shapes3_FA8+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libso_shapes3_FA8
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
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #14
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _libso_shapes3_FA9+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _libso_shapes3_FA9
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
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _libso_shapes3_L20
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #10
                BEQ     *+5
                BRL     _libso_shapes3_L20
                LDA     #1
                BRL     _libso_shapes3_L21
_libso_shapes3_L20
                LDA     #0
_libso_shapes3_L21
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes3_L18
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _libso_shapes3_L18
                LDA     #1
                BRL     _libso_shapes3_L19
_libso_shapes3_L18
                LDA     #0
_libso_shapes3_L19
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes3_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #6
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _libso_shapes3_L22-1
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
_libso_shapes3_L22
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _libso_shapes3_L16
                LDA     #1
                BRL     _libso_shapes3_L17
_libso_shapes3_L16
                LDA     #0
_libso_shapes3_L17
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes3_L14
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #6
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _libso_shapes3_L23-1
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
_libso_shapes3_L23
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _libso_shapes3_L14
                LDA     #1
                BRL     _libso_shapes3_L15
_libso_shapes3_L14
                LDA     #0
_libso_shapes3_L15
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes3_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _libc_blk_libso_shapes3
                CLC
                ADC     #14
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _libso_shapes3_L24-1
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
_libso_shapes3_L24
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #5
                BEQ     *+5
                BRL     _libso_shapes3_L12
                LDA     #1
                BRL     _libso_shapes3_L13
_libso_shapes3_L12
                LDA     #0
_libso_shapes3_L13
                CMP     #0
                BNE     *+5
                BRL     _libso_shapes3_L10
                LDA     #42
                BRL     _libso_shapes3_L11
_libso_shapes3_L10
                LDA     #1
_libso_shapes3_L11
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
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
