                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from wait3ops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                TSC
                SEC
                SBC     #main_FRAMESIZE-6
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
                AND     #$00FF
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     _fcc_img18
_wait3ops_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                SEC
                SBC     #76
                BVC     _wait3ops_L3
                EOR     #$8000
_wait3ops_L3
                BPL     _wait3ops_L2
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     _fcc_img18
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
                INC     _fcc_img18
                BRA     _wait3ops_L0
_wait3ops_L2
                LDA     #0
                STA     _fcc_img18
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_img0
_wait3ops_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                SEC
                SBC     #76
                BVC     _wait3ops_L7
                EOR     #$8000
_wait3ops_L7
                BPL     _wait3ops_L6
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     _fcc_img18
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #90
                BNE     _wait3ops_L8
                LDA     #1
                STA     _fcc_img0
_wait3ops_L8
_wait3ops_L5
                INC     _fcc_img18
                BRA     _wait3ops_L4
_wait3ops_L6
                LDA     _fcc_img0
                STA     9,S   ; fccstk d=0 b=9
                BEQ     _wait3ops_L9
                LDA     5,S   ; fccstk d=0 b=5
                TAX
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
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _wait3ops_L11
                EOR     #$8000
_wait3ops_L11
                BPL     _wait3ops_L10
                LDA     5,S   ; fccstk d=0 b=5
                TAX
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
                BNE     _wait3ops_L12
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L12
                LDA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BNE     _wait3ops_L13
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L13
                LDA     #0
                STA     _fcc_img18
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_img1
_wait3ops_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                SEC
                SBC     #76
                BVC     _wait3ops_L17
                EOR     #$8000
_wait3ops_L17
                BPL     _wait3ops_L16
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     _fcc_img18
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #0
                BEQ     _wait3ops_L18
                LDA     #0
                STA     _fcc_img1
_wait3ops_L18
_wait3ops_L15
                INC     _fcc_img18
                BRA     _wait3ops_L14
_wait3ops_L16
                LDA     _fcc_img1
                STA     11,S   ; fccstk d=0 b=11
                BEQ     _wait3ops_L19
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_wait3ops_L19
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-6
                TCS
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     98
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
