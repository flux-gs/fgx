                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dirchurn.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT getall
getall            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img22
                PEI     _fcc_img23
                PEI     _fcc_img24
                PEI     _fcc_img25
                PEI     _fcc_img26
                TSC
                SEC
                SBC     #getall_FRAMESIZE-22
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
                STA     _fcc_img24
                LDA     #0
                STA     _fcc_img25
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
                LDA     _fcc_img24
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
                LDA     _fcc_img24
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
                LDA     _fcc_img25
                TAX
                SEC
                SBC     #46
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img25
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nbuf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #10
                TCS
                LDA     _fcc_img25
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L4
                EOR     #$8000
_dirchurn_L4
                BPL     _dirchurn_L3
                LDY     #2
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L3
                LDA     #$FFEC
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
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
                LDA     _fcc_img25
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L6
                EOR     #$8000
_dirchurn_L6
                BPL     _dirchurn_L5
                LDY     #2
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L5
                LDA     #$FFF3
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_img25
                STA     [_fcc_fpr0]
                LDA     _fcc_img25
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L8
                EOR     #$8000
_dirchurn_L8
                BPL     _dirchurn_L7
                LDY     #2
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L7
                LDA     #$FFF1
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L7
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nbuf
                STA     _fcc_fpr1
                PLA
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
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirchurn_L10
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirchurn_L10
                LDA     #1
                BRA     _dirchurn_L11
_dirchurn_L10
                LDA     #0
_dirchurn_L11
                CMP     #0
                BEQ     _dirchurn_L9
                LDA     #$FFFE
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L9
                LDA     _fcc_img25
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L13
                EOR     #$8000
_dirchurn_L13
                BPL     _dirchurn_L12
                LDY     #2
                LDA     [_fcc_img18],Y
                PHA
                INY
                INY
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L12
                LDA     #$FFF2
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L12
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #28
                STA     1,S   ; fccstk d=0 b=1
                INC     _fcc_img25
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
                BNE     _dirchurn_L15
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirchurn_L15
                LDA     #1
                BRA     _dirchurn_L16
_dirchurn_L15
                LDA     #0
_dirchurn_L16
                CMP     #0
                BNE     *+5
                BRL     _dirchurn_L14
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
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
                STA     _fcc_img21
                LDA     _fcc_fpr0
                STA     _fcc_img20
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L17
                LDA     #$FFF6
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L17
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
                LDA     _fcc_img24
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
                LDA     _fcc_img21
                STA     _fcc_fpr1+2
                LDA     _fcc_img20
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _dirchurn_L19
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirchurn_L19
                LDA     #1
                BRA     _dirchurn_L20
_dirchurn_L19
                LDA     #0
_dirchurn_L20
                CMP     #0
                BEQ     _dirchurn_L18
                LDA     #$FFEE
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L18
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
                BNE     _dirchurn_L22
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirchurn_L22
                LDA     #1
                BRA     _dirchurn_L23
_dirchurn_L22
                LDA     #0
_dirchurn_L23
                CMP     #0
                BEQ     _dirchurn_L21
                LDA     #$FFFD
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L21
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L24
                LDA     #$FFF5
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L24
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
                LDA     _fcc_img24
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
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
                STA     _fcc_fpr1
                LDA     _fcc_img24
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
                BNE     _dirchurn_L26
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _dirchurn_L26
                LDA     #0
                BRA     _dirchurn_L27
_dirchurn_L26
                LDA     #1
_dirchurn_L27
                CMP     #0
                BEQ     _dirchurn_L25
                LDA     #$FFF0
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L25
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img23
                LDA     _fcc_fpr0
                STA     _fcc_img22
                LDA     _fcc_img24
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                STA     _fcc_img26
_dirchurn_L28
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img26
                TAX
                LDA     _fcc_img24
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
                BVC     _dirchurn_L31
                EOR     #$8000
_dirchurn_L31
                BPL     _dirchurn_L30
                LDA     _fcc_img23
                STA     _fcc_ptr+2
                LDA     _fcc_img22
                PHA
                LDA     _fcc_img26
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
_dirchurn_L29
                INC     _fcc_img26
                BRA     _dirchurn_L28
_dirchurn_L30
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L32
                LDA     #$FFEF
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRL     getall_bandx
_dirchurn_L32
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
                LDA     _fcc_img24
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
                LDA     _fcc_img24
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                STA     _fcc_img24
                LDY     #2
                LDA     [_fcc_img16],Y
                PHA
                INY
                INY
                LDA     [_fcc_img16],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L33
                LDA     #$FFF4
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
                BRA     getall_bandx
_dirchurn_L33
_dirchurn_L14
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
                LDA     _fcc_img25
                TAY
                TSC
                CLC
                ADC     #getall_FRAMESIZE-22
                TCS
getall_bandx
                PLA
                STA     _fcc_img26
                PLA
                STA     _fcc_img25
                PLA
                STA     _fcc_img24
                PLA
                STA     _fcc_img23
                PLA
                STA     _fcc_img22
                PLA
                STA     _fcc_img21
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
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
getall_FRAMESIZE   EQU     48
getall_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
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
                STA     _fcc_img17
                CMP     #$FFF6
                BNE     _dirchurn_L34
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L34
                LDA     _fcc_img17
                CMP     #$FFF5
                BNE     _dirchurn_L35
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L35
                LDA     _fcc_img17
                CMP     #$FFF4
                BNE     _dirchurn_L36
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L36
                LDA     _fcc_img17
                CMP     #$FFEC
                BNE     _dirchurn_L37
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L37
                LDA     _fcc_img17
                CMP     #$FFF3
                BNE     _dirchurn_L38
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L38
                LDA     _fcc_img17
                CMP     #$FFF1
                BNE     _dirchurn_L39
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L39
                LDA     _fcc_img17
                CMP     #$FFF2
                BNE     _dirchurn_L40
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L40
                LDA     _fcc_img17
                CMP     #$FFF0
                BNE     _dirchurn_L41
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L41
                LDA     _fcc_img17
                CMP     #$FFEF
                BNE     _dirchurn_L42
                LDA     #58
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L42
                LDA     _fcc_img17
                CMP     #$FFEE
                BNE     _dirchurn_L43
                LDA     #59
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L43
                LDA     _fcc_img17
                BPL     _dirchurn_L44
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L44
                LDA     _fcc_img17
                TAX
                SEC
                SBC     #20
                BVC     _dirchurn_L46
                EOR     #$8000
_dirchurn_L46
                BPL     _dirchurn_L45
                LDA     #60
                CLC
                ADC     _fcc_img17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L45
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     _fcc_img16
_dirchurn_L47
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                LDA     _fcc_img17
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L50
                EOR     #$8000
_dirchurn_L50
                BMI     *+5
                BRL     _dirchurn_L49
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     _fcc_img16
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _dirchurn_L51
                LDA     #200
                PHA
                LDA     _fcc_img16
                LDX     #54
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L54
                EOR     #$8000
_dirchurn_L54
                BPL     _dirchurn_L52
                LDA     #54
                BRA     _dirchurn_L53
_dirchurn_L52
                LDA     _fcc_img16
_dirchurn_L53
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_dirchurn_L51
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #110
                BEQ     _dirchurn_L55
                LDA     #100
                PHA
                LDA     _fcc_img16
                LDX     #54
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dirchurn_L58
                EOR     #$8000
_dirchurn_L58
                BPL     _dirchurn_L56
                LDA     #54
                BRA     _dirchurn_L57
_dirchurn_L56
                LDA     _fcc_img16
_dirchurn_L57
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_dirchurn_L55
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #28
                STA     5,S   ; fccstk d=0 b=5
_dirchurn_L48
                INC     _fcc_img16
                BRL     _dirchurn_L47
_dirchurn_L49
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
                ADC     #main_FRAMESIZE-4
                TCS
main_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     22
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
