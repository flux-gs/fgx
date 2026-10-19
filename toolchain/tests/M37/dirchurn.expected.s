                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dirchurn.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT getall
getall            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getall_FRAMESIZE
                DO      getall_STKGUARD
                BCC     getall_stkovf
                CMP     _fcc_stkfloor
                BCS     getall_stkok
getall_stkovf       JMP     _fcc_stkoflow
                FIN
getall_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #20
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #28
                PHA
                LDA     11,S   ; fccstk d=6 b=5
                PHA
                FGX2_FARCALL calloc
                TAY
                PLA
                PLA
                TYA
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDA     _fcc_fpr1
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                DO      16+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getall_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getall_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_fpr0
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
_dirchurn_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #46
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L2
                EOR     #$8000
_dirchurn_L2
                BMI     *+5
                BRL     _dirchurn_L1
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     7,S   ; fccstk d=0 b=7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_dirchurn_S0
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
                LDA     #nbuf
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #10
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L6
                EOR     #$8000
_dirchurn_L6
                BMI     *+5
                BRL     _dirchurn_L4
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L4
                LDA     #1
                BRL     _dirchurn_L5
_dirchurn_L4
                LDA     #0
_dirchurn_L5
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L3
                LDA     #20
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L3
                LDA     #28
                PHA
                LDA     #0
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L10
                EOR     #$8000
_dirchurn_L10
                BMI     *+5
                BRL     _dirchurn_L8
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L8
                LDA     #1
                BRL     _dirchurn_L9
_dirchurn_L8
                LDA     #0
_dirchurn_L9
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L7
                LDA     #13
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L7
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                STA     [_fcc_fpr0]
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L14
                EOR     #$8000
_dirchurn_L14
                BMI     *+5
                BRL     _dirchurn_L12
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L12
                LDA     #1
                BRL     _dirchurn_L13
_dirchurn_L12
                LDA     #0
_dirchurn_L13
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L11
                LDA     #15
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L11
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nbuf
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL strdup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _dirchurn_L16
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _dirchurn_L16
                LDA     #1
                BRL     _dirchurn_L17
_dirchurn_L16
                LDA     #0
_dirchurn_L17
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L15
                LDA     #2
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L15
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L21
                EOR     #$8000
_dirchurn_L21
                BMI     *+5
                BRL     _dirchurn_L19
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L19
                LDA     #1
                BRL     _dirchurn_L20
_dirchurn_L19
                LDA     #0
_dirchurn_L20
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L18
                LDA     #14
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L18
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #28
                STA     1,S   ; fccstk d=0 b=1
                LDA     7,S   ; fccstk d=0 b=7
                INC
                STA     7,S   ; fccstk d=0 b=7
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                DO      14+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getall_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_ptr
                DO      16+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getall_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _dirchurn_L23
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _dirchurn_L23
                LDA     #1
                BRL     _dirchurn_L24
_dirchurn_L23
                LDA     #0
_dirchurn_L24
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L22
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L25
                LDA     #10
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L25
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=4 b=5
                ASL
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      18+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+getall_FRAMESIZE,S   ; fccstk d=8 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      20+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+getall_FRAMESIZE,S   ; fccstk d=8 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL realloc
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     19,S   ; fccstk d=0 b=19
                STA     _fcc_fpr1+2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _dirchurn_L27
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _dirchurn_L27
                LDA     #1
                BRL     _dirchurn_L28
_dirchurn_L27
                LDA     #0
_dirchurn_L28
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L26
                LDA     #18
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L26
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _dirchurn_L30
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _dirchurn_L30
                LDA     #1
                BRL     _dirchurn_L31
_dirchurn_L30
                LDA     #0
_dirchurn_L31
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L29
                LDA     #3
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L29
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L32
                LDA     #11
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L32
                DO      10+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getall_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getall_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr1+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr1
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _dirchurn_L34
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _dirchurn_L34
                LDA     #0
                BRL     _dirchurn_L35
_dirchurn_L34
                LDA     #1
_dirchurn_L35
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L33
                LDA     #16
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L33
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     23,S   ; fccstk d=0 b=23
                LDA     _fcc_fpr0
                STA     21,S   ; fccstk d=0 b=21
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                STA     25,S   ; fccstk d=0 b=25
                STA     _fcc_img0
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img1
_dirchurn_L36
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                ASL
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L39
                EOR     #$8000
_dirchurn_L39
                BMI     *+5
                BRL     _dirchurn_L38
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_ptr+2
                LDA     21,S   ; fccstk d=0 b=21
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
                LDA     #85
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
_dirchurn_L37
                INC     _fcc_img0
                BRL     _dirchurn_L36
_dirchurn_L38
                LDA     _fcc_img0
                STA     25,S   ; fccstk d=0 b=25
                LDA     _fcc_img1
                STA     5,S   ; fccstk d=0 b=5
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L40
                LDA     #17
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L40
                DO      16+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getall_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getall_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                STA     5,S   ; fccstk d=0 b=5
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L41
                LDA     #12
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L41
_dirchurn_L22
                BRL     _dirchurn_L0
_dirchurn_L1
                DO      16+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+getall_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+getall_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+getall_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+getall_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_fpr0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr1+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getall_FRAMESIZE   EQU     26
getall_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_dirchurn_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL getall
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #10
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L42
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L42
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #11
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L43
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L43
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #12
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L44
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L44
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #20
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L45
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L45
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #13
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L46
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L46
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #15
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L47
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L47
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #14
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L48
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L48
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #16
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L49
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L49
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #17
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L50
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L50
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #18
                EOR     #$FFFF
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _dirchurn_L51
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L51
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L53
                EOR     #$8000
_dirchurn_L53
                BMI     *+5
                BRL     _dirchurn_L52
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
_dirchurn_L52
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #20
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L55
                EOR     #$8000
_dirchurn_L55
                BMI     *+5
                BRL     _dirchurn_L54
                LDA     #60
                CLC
                ADC     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L54
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     15,S   ; fccstk d=0 b=15
                STA     _fcc_img0
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_img1
_dirchurn_L56
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L59
                EOR     #$8000
_dirchurn_L59
                BMI     *+5
                BRL     _dirchurn_L58
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L60
                LDA     #200
                PHA
                LDA     _fcc_img0
                TAX
                LDA     #54
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L63
                EOR     #$8000
_dirchurn_L63
                BMI     *+5
                BRL     _dirchurn_L61
                LDA     #54
                BRL     _dirchurn_L62
_dirchurn_L61
                LDA     _fcc_img0
_dirchurn_L62
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L60
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                LDA     #110
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _dirchurn_L64
                LDA     #100
                PHA
                LDA     _fcc_img0
                TAX
                LDA     #54
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L67
                EOR     #$8000
_dirchurn_L67
                BMI     *+5
                BRL     _dirchurn_L65
                LDA     #54
                BRL     _dirchurn_L66
_dirchurn_L65
                LDA     _fcc_img0
_dirchurn_L66
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_dirchurn_L64
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #28
                STA     5,S   ; fccstk d=0 b=5
_dirchurn_L57
                INC     _fcc_img0
                BRL     _dirchurn_L56
_dirchurn_L58
                LDA     _fcc_img0
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_img1
                STA     13,S   ; fccstk d=0 b=13
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
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
