                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from wait3ops.c
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
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
                LDA     #argv_tab
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nm
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #argv_tab
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_img0
_wait3ops_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #76
                BVC     _wait3ops_L3
                EOR     #$8000
_wait3ops_L3
                BMI     *+5
                BRL     _wait3ops_L2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
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
                LDA     #90
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
_wait3ops_L1
                INC     _fcc_img0
                BRL     _wait3ops_L0
_wait3ops_L2
                LDA     _fcc_img0
                STA     7,S   ; fccstk d=0 b=7
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_img1
_wait3ops_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                SEC
                SBC     #76
                BVC     _wait3ops_L7
                EOR     #$8000
_wait3ops_L7
                BMI     *+5
                BRL     _wait3ops_L6
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _wait3ops_L8
                LDA     #1
                STA     _fcc_img1
_wait3ops_L8
_wait3ops_L5
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #1
                STA     7,S   ; fccstk d=0 b=7
                BRL     _wait3ops_L4
_wait3ops_L6
                LDA     _fcc_img1
                STA     9,S   ; fccstk d=0 b=9
                CMP     #0
                BNE     *+5
                BRL     _wait3ops_L9
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L9
                LDA     #4660
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #argv_tab
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nm
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL spawnv
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _wait3ops_L11
                EOR     #$8000
_wait3ops_L11
                BMI     *+5
                BRL     _wait3ops_L10
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L10
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL wait3
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _wait3ops_L12
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L12
                LDA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BEQ     *+5
                BRL     _wait3ops_L13
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L13
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_img2
_wait3ops_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                SEC
                SBC     #76
                BVC     _wait3ops_L17
                EOR     #$8000
_wait3ops_L17
                BMI     *+5
                BRL     _wait3ops_L16
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #0
                BNE     *+5
                BRL     _wait3ops_L18
                LDA     #0
                STA     _fcc_img2
_wait3ops_L18
_wait3ops_L15
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #1
                STA     7,S   ; fccstk d=0 b=7
                BRL     _wait3ops_L14
_wait3ops_L16
                LDA     _fcc_img2
                STA     11,S   ; fccstk d=0 b=11
                CMP     #0
                BNE     *+5
                BRL     _wait3ops_L19
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L19
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     92
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
