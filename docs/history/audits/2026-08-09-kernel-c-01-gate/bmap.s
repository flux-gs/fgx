                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from docs/history/audits/2026-08-09-kernel-c-01-gate/bmap.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT bmap
bmap            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bmap_FRAMESIZE
                DO      bmap_STKGUARD
                BCC     bmap_stkovf
                CMP     _fcc_stkfloor
                BCS     bmap_stkok
bmap_stkovf       JMP     _fcc_stkoflow
                FIN
bmap_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #52
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #54
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     #64
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                STA     27,S   ; fccstk d=0 b=27
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _bmap_L0
                LDA     #27
                STA     u+0
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bmap_L0
                LDA     #0
                JSR     _fcc_long_from_int
                STA     rablock
                TAY
                LDA     _fcc_long_hi
                STA     rablock+2
                TYA
                STA     23,S   ; fccstk d=0 b=23
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     25,S   ; fccstk d=0 b=25
                TYA
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #7
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _bmap_L1
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #24
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
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
                BRL     _bmap_L2
                DO      14+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+bmap_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L3
                DO      16+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+bmap_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                PHA
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL balloc
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _bmap_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _bmap_L5
                LDA     #1
                BRL     _bmap_L6
_bmap_L5
                LDA     #0
_bmap_L6
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L3
                LDA     #0
                BRL     _bmap_L4
_bmap_L3
                LDA     #1
_bmap_L4
                CMP     #0
                BNE     *+5
                BRL     _bmap_L7
                LDA     #1
                EOR     #$FFFF
                INC
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bmap_L7
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_fpr0],Y
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
                JSR     _fcc_long_shr
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                DO      16+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+bmap_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                CMP     #0
                BNE     *+5
                BRL     _bmap_L8
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _bmap_L9
_bmap_L8
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                TSC
                CLC
                ADC     #4
                TCS
_bmap_L9
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #24
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #2
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                ORA     _fcc_tmp_b
                LDY     #8
                STA     [_fcc_fpr0],Y
_bmap_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #7
                TAY
                LDA     #4
                STA     _fcc_tmp_b
                TYA
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BNE     *+5
                BRL     _bmap_L10
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #24
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                STA     rablock
                TAY
                LDA     _fcc_long_hi
                STA     rablock+2
                TYA
_bmap_L10
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bmap_L1
                LDA     #0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #1
                STA     15,S   ; fccstk d=0 b=15
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #7
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                DO      10+bmap_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                DO      12+bmap_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #14+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                TYA
                LDA     #3
                STA     11,S   ; fccstk d=0 b=11
                STA     _fcc_img0
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_img1
_bmap_L11
                LDA     _fcc_img0
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_gts16
                CMP     #0
                BNE     *+5
                BRL     _bmap_L13
                LDA     _fcc_img1
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #8
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shl
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     21,S   ; fccstk d=4 b=17
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=4 b=15
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BNE     *+5
                BRL     _bmap_L14
                BRL     _bmap_L13
_bmap_L14
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     21,S   ; fccstk d=4 b=17
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=4 b=15
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                DO      10+bmap_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                DO      12+bmap_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #14+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                TYA
_bmap_L12
                DEC     _fcc_img0
                BRL     _bmap_L11
_bmap_L13
                LDA     _fcc_img0
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_img1
                STA     13,S   ; fccstk d=0 b=13
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BNE     *+5
                BRL     _bmap_L15
                LDA     #27
                STA     u+0
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bmap_L15
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #24
                STA     _fcc_fpr0
                LDA     #7
                SEC
                SBC     11,S   ; fccstk d=0 b=11
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
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
                BRL     _bmap_L16
                DO      14+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+bmap_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L17
                DO      16+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+bmap_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                PHA
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL balloc
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _bmap_L19
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _bmap_L19
                LDA     #1
                BRL     _bmap_L20
_bmap_L19
                LDA     #0
_bmap_L20
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L17
                LDA     #0
                BRL     _bmap_L18
_bmap_L17
                LDA     #1
_bmap_L18
                CMP     #0
                BNE     *+5
                BRL     _bmap_L21
                LDA     #1
                EOR     #$FFFF
                INC
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bmap_L21
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_fpr0],Y
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
                JSR     _fcc_long_shr
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     27,S   ; fccstk d=0 b=27
                CMP     #0
                BNE     *+5
                BRL     _bmap_L22
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _bmap_L23
_bmap_L22
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TSC
                CLC
                ADC     #4
                TCS
_bmap_L23
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #24
                STA     _fcc_fpr0
                LDA     #7
                SEC
                SBC     11,S   ; fccstk d=0 b=11
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bmap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     #2
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                ORA     _fcc_tmp_b
                LDY     #8
                STA     [_fcc_fpr0],Y
_bmap_L16
_bmap_L24
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_les16
                CMP     #0
                BNE     *+5
                BRL     _bmap_L26
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                FGX2_FARCALL bread
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L27
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L27
                LDA     #0
                BRL     _bmap_L28
_bmap_L27
                LDA     #1
_bmap_L28
                CMP     #0
                BNE     *+5
                BRL     _bmap_L29
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bmap_L29
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_fpr0
                STA     19,S   ; fccstk d=0 b=19
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
                DO      12+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+bmap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     17,S   ; fccstk d=4 b=13
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shr
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #255
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     1,S   ; fccstk d=0 b=1
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_ptr+2
                LDA     19,S   ; fccstk d=0 b=19
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #256
                TAY
                LDA     #1
                STA     _fcc_tmp_b
                TYA
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BNE     *+5
                BRL     _bmap_L30
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_ptr+2
                LDA     19,S   ; fccstk d=0 b=19
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                CLC
                ADC     #2
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                STA     23,S   ; fccstk d=0 b=23
                TAY
                LDA     _fcc_long_hi
                STA     25,S   ; fccstk d=0 b=25
                TYA
_bmap_L30
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
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
                BRL     _bmap_L31
                DO      14+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+bmap_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L32
                DO      16+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+bmap_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                PHA
                DO      10+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+bmap_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+bmap_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL balloc
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                STA     7,S   ; fccstk d=0 b=7
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _bmap_L34
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _bmap_L34
                LDA     #1
                BRL     _bmap_L35
_bmap_L34
                LDA     #0
_bmap_L35
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L32
                LDA     #0
                BRL     _bmap_L33
_bmap_L32
                LDA     #1
_bmap_L33
                CMP     #0
                BNE     *+5
                BRL     _bmap_L36
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #1
                EOR     #$FFFF
                INC
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bmap_L36
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #6
                LDA     [_fcc_fpr0],Y
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
                JSR     _fcc_long_shr
                STA     15,S   ; fccstk d=0 b=15
                TAY
                LDA     _fcc_long_hi
                STA     17,S   ; fccstk d=0 b=17
                TYA
                LDA     27,S   ; fccstk d=0 b=27
                CMP     #0
                BEQ     _bmap_L37
                LDA     #0
                BRA     _bmap_L38
_bmap_L37
                LDA     #1
_bmap_L38
                CMP     #0
                BNE     *+5
                BRL     _bmap_L39
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L41
                DO      16+bmap_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+bmap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+bmap_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                CMP     #0
                BEQ     *+5
                BRL     _bmap_L41
                LDA     #0
                BRL     _bmap_L42
_bmap_L41
                LDA     #1
_bmap_L42
                CMP     #0
                BNE     *+5
                BRL     _bmap_L39
                LDA     #1
                BRL     _bmap_L40
_bmap_L39
                LDA     #0
_bmap_L40
                CMP     #0
                BNE     *+5
                BRL     _bmap_L43
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bwrite
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _bmap_L44
_bmap_L43
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                TSC
                CLC
                ADC     #4
                TCS
_bmap_L44
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #14
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     21,S   ; fccstk d=0 b=21
                LDA     _fcc_fpr0
                STA     19,S   ; fccstk d=0 b=19
                LDA     21,S   ; fccstk d=0 b=21
                STA     _fcc_ptr+2
                LDA     19,S   ; fccstk d=0 b=19
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                ASL
                ASL
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
                LDA     21,S   ; fccstk d=4 b=17
                STA     _fcc_long_hi
                LDA     19,S   ; fccstk d=4 b=15
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bdwrite
                TSC
                CLC
                ADC     #4
                TCS
                BRL     _bmap_L45
_bmap_L31
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL brelse
                TSC
                CLC
                ADC     #4
                TCS
_bmap_L45
_bmap_L25
                LDA     11,S   ; fccstk d=0 b=11
                CLC
                ADC     #1
                STA     11,S   ; fccstk d=0 b=11
                BRL     _bmap_L24
_bmap_L26
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_long_hi
                LDA     23,S   ; fccstk d=0 b=23
                STA     rablock
                TAY
                LDA     _fcc_long_hi
                STA     rablock+2
                TYA
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=0 b=15
                TAY
                TSC
                CLC
                ADC     #bmap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bmap_FRAMESIZE   EQU     28
bmap_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 16
