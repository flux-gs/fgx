                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from getoptops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT streq
streq            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #streq_FRAMESIZE
                DO      streq_STKGUARD
                BCC     streq_stkovf
                CMP     _fcc_stkfloor
                BCS     streq_stkok
streq_stkovf       JMP     _fcc_stkoflow
                FIN
streq_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+streq_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+streq_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+streq_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+streq_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img0
_getoptops_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L2
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _getoptops_L2
                LDA     #1
                BRL     _getoptops_L3
_getoptops_L2
                LDA     #0
_getoptops_L3
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L1
                INC     _fcc_img0
                BRL     _getoptops_L0
_getoptops_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_eq16
                TAY
                TSC
                CLC
                ADC     #streq_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
streq_FRAMESIZE   EQU     2
streq_STKGUARD    EQU     0
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
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                LDA     #0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #av
                PHA
                LDA     #0
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S0
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
                LDA     #av
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S1
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
                LDA     #av
                PHA
                LDA     #2
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S2
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
                LDA     #av
                PHA
                LDA     #3
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S3
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
                LDA     #av
                PHA
                LDA     #4
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S4
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
                LDA     #av
                PHA
                LDA     #5
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S5
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
                LDA     #av
                PHA
                LDA     #6
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S6
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
                LDA     #av
                PHA
                LDA     #7
                ASL
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #0
                STA     opterr
_getoptops_L4
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
                LDA     #_getoptops_S7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #av
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #7
                PHA
                FGX2_FARCALL getopt
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                CMP     #$FFFF
                BNE     *+5
                BRL     _getoptops_L5
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #108
                BEQ     *+5
                BRL     _getoptops_L6
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                ORA     #1
                STA     5,S   ; fccstk d=0 b=5
                BRL     _getoptops_L7
_getoptops_L6
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _getoptops_L8
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                ORA     #2
                STA     5,S   ; fccstk d=0 b=5
                BRL     _getoptops_L9
_getoptops_L8
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #111
                BEQ     *+5
                BRL     _getoptops_L10
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     optarg+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     optarg
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L11
                LDA     #1
                STA     9,S   ; fccstk d=0 b=9
_getoptops_L11
                BRL     _getoptops_L12
_getoptops_L10
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #102
                BEQ     *+5
                BRL     _getoptops_L13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     optarg+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     optarg
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L14
                LDA     #1
                STA     7,S   ; fccstk d=0 b=7
_getoptops_L14
                BRL     _getoptops_L15
_getoptops_L13
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #63
                BEQ     *+5
                BRL     _getoptops_L16
                LDA     optopt
                TAX
                TXA
                CMP     #122
                BEQ     *+5
                BRL     _getoptops_L17
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
_getoptops_L17
                BRL     _getoptops_L18
_getoptops_L16
                LDA     #$FFFF
                STA     13,S   ; fccstk d=0 b=13
_getoptops_L18
_getoptops_L15
_getoptops_L12
_getoptops_L9
_getoptops_L7
                BRL     _getoptops_L4
_getoptops_L5
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _getoptops_L19
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_getoptops_L19
                LDA     9,S   ; fccstk d=0 b=9
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L20
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_getoptops_L20
                LDA     7,S   ; fccstk d=0 b=7
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L21
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_getoptops_L21
                LDA     11,S   ; fccstk d=0 b=11
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L22
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_getoptops_L22
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _getoptops_L23
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_getoptops_L23
                LDA     optind
                TAX
                TXA
                CMP     #6
                BEQ     *+5
                BRL     _getoptops_L24
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_getoptops_L24
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_getoptops_S6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     optind
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    av+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    av,X
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _getoptops_L25
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_getoptops_L25
                LDA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 7
