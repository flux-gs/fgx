                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from structval.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT mk
mk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mk_FRAMESIZE
                DO      mk_STKGUARD
                BCC     mk_stkovf
                CMP     _fcc_stkfloor
                BCS     mk_stkok
mk_stkovf       JMP     _fcc_stkoflow
                FIN
mk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g2
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #mk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mk_FRAMESIZE   EQU     0
mk_STKGUARD    EQU     0
                FGX2_EXPORT _structval_take
_structval_take            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_structval_take_FRAMESIZE
                DO      _structval_take_STKGUARD
                BCC     _structval_take_stkovf
                CMP     _fcc_stkfloor
                BCS     _structval_take_stkok
_structval_take_stkovf       JMP     _fcc_stkoflow
                FIN
_structval_take_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_structval_take_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structval_take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structval_take_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      14+_structval_take_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_structval_take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_structval_take_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _structval_L2
                DO      8+_structval_take_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structval_take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structval_take_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                PHA
                DO      16+_structval_take_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_structval_take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_structval_take_FRAMESIZE,S   ; fccstk d=2 b=14 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _structval_L2
                LDA     #1
                BRL     _structval_L3
_structval_L2
                LDA     #0
_structval_L3
                CMP     #0
                BNE     *+5
                BRL     _structval_L0
                DO      10+_structval_take_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structval_take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structval_take_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                DO      18+_structval_take_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_structval_take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_structval_take_FRAMESIZE,S   ; fccstk d=2 b=16 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _structval_L0
                LDA     #1
                BRL     _structval_L1
_structval_L0
                LDA     #0
_structval_L1
                TAY
                TSC
                CLC
                ADC     #_structval_take_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structval_take_FRAMESIZE   EQU     0
_structval_take_STKGUARD    EQU     0
                FGX2_EXPORT _structval_same
_structval_same            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_structval_same_FRAMESIZE
                DO      _structval_same_STKGUARD
                BCC     _structval_same_stkovf
                CMP     _fcc_stkfloor
                BCS     _structval_same_stkok
_structval_same_stkovf       JMP     _fcc_stkoflow
                FIN
_structval_same_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structval_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structval_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      12+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_structval_same_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _structval_L6
                DO      8+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structval_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structval_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                DO      14+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_structval_same_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _structval_L6
                LDA     #1
                BRL     _structval_L7
_structval_L6
                LDA     #0
_structval_L7
                CMP     #0
                BNE     *+5
                BRL     _structval_L4
                DO      8+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structval_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structval_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                DO      16+_structval_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_structval_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_structval_same_FRAMESIZE,S   ; fccstk d=2 b=14 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _structval_L4
                LDA     #1
                BRL     _structval_L5
_structval_L4
                LDA     #0
_structval_L5
                TAY
                TSC
                CLC
                ADC     #_structval_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structval_same_FRAMESIZE   EQU     0
_structval_same_STKGUARD    EQU     0
                FGX2_EXPORT _structval_fill
_structval_fill            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_structval_fill_FRAMESIZE
                DO      _structval_fill_STKGUARD
                BCC     _structval_fill_stkovf
                CMP     _fcc_stkfloor
                BCS     _structval_fill_stkok
_structval_fill_stkovf       JMP     _fcc_stkoflow
                FIN
_structval_fill_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     [_fcc_fpr0]
                DO      8+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                TXA
                INC
                LDY     #2
                STA     [_fcc_fpr0],Y
                DO      8+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+_structval_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structval_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structval_fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                TXA
                INC
                INC
                LDY     #4
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #_structval_fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structval_fill_FRAMESIZE   EQU     0
_structval_fill_STKGUARD    EQU     0
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
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
                LDA     #10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g0
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #13
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _structval_g0+22
                TAY
                LDA     _fcc_ptr+2
                STA     _structval_g0+24
                TYA
                LDA     #20
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g1
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #23
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g1
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #30
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g2
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #33
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g2
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #40
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #43
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_fill
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g0
                STA     _structval_gp
                LDA     _fcc_fpr0+2
                STA     _structval_gp+2
                LDA     #12
                PHA
                LDA     #11
                PHA
                LDA     #10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
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
                INC
                INC
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_structval_L13
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _structval_L13
                FGX2_FARCALL _structval_take
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L11
                LDA     #22
                PHA
                LDA     #21
                PHA
                LDA     #20
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
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
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                INC
                INC
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_structval_L14
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _structval_L14
                FGX2_FARCALL _structval_take
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L11
                LDA     #1
                BRL     _structval_L12
_structval_L11
                LDA     #0
_structval_L12
                CMP     #0
                BNE     *+5
                BRL     _structval_L9
                LDA     #32
                PHA
                LDA     #31
                PHA
                LDA     #30
                PHA
                FGX2_FARCALL mk
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_structval_L15
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _structval_L15
                FGX2_FARCALL _structval_take
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L9
                LDA     #1
                BRL     _structval_L10
_structval_L9
                LDA     #0
_structval_L10
                CMP     #0
                BNE     *+5
                BRL     _structval_L8
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_structval_L8
                LDA     #15
                PHA
                LDA     #14
                PHA
                LDA     #13
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
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
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_structval_L23
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _structval_L23
                FGX2_FARCALL _structval_take
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L21
                LDA     #25
                PHA
                LDA     #24
                PHA
                LDA     #23
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
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
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_structval_L24
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _structval_L24
                FGX2_FARCALL _structval_take
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L21
                LDA     #1
                BRL     _structval_L22
_structval_L21
                LDA     #0
_structval_L22
                CMP     #0
                BNE     *+5
                BRL     _structval_L19
                LDA     #35
                PHA
                LDA     #34
                PHA
                LDA     #33
                PHA
                FGX2_FARCALL mk
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_structval_L25
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _structval_L25
                FGX2_FARCALL _structval_take
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L19
                LDA     #1
                BRL     _structval_L20
_structval_L19
                LDA     #0
_structval_L20
                CMP     #0
                BNE     *+5
                BRL     _structval_L17
                LDA     #45
                PHA
                LDA     #44
                PHA
                LDA     #43
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_structval_L26
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _structval_L26
                FGX2_FARCALL _structval_take
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L17
                LDA     #1
                BRL     _structval_L18
_structval_L17
                LDA     #0
_structval_L18
                CMP     #0
                BNE     *+5
                BRL     _structval_L16
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_structval_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
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
                INC
                INC
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #12
                BEQ     *+5
                BRL     _structval_L32
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #41
                BEQ     *+5
                BRL     _structval_L32
                LDA     #1
                BRL     _structval_L33
_structval_L32
                LDA     #0
_structval_L33
                CMP     #0
                BNE     *+5
                BRL     _structval_L30
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #44
                BEQ     *+5
                BRL     _structval_L30
                LDA     #1
                BRL     _structval_L31
_structval_L30
                LDA     #0
_structval_L31
                CMP     #0
                BNE     *+5
                BRL     _structval_L28
                LDA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BNE     *+5
                BRL     _structval_L34
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
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
                LDY     #22
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #2
                STA     _fcc_fpr0
                BRL     _structval_L35
_structval_L34
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                INC
                INC
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
_structval_L35
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #20
                BEQ     *+5
                BRL     _structval_L28
                LDA     #1
                BRL     _structval_L29
_structval_L28
                LDA     #0
_structval_L29
                CMP     #0
                BNE     *+5
                BRL     _structval_L27
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_structval_L27
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr1
                LDY     #22
                LDA     [_fcc_fpr1],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #24
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #2
                STA     _fcc_fpr1
                LDY     #4
_structval_L36
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structval_L36
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #1
                BEQ     *+5
                BRL     _structval_L38
                LDA     #22
                PHA
                LDA     #21
                PHA
                LDA     #20
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L38
                LDA     #1
                BRL     _structval_L39
_structval_L38
                LDA     #0
_structval_L39
                CMP     #0
                BNE     *+5
                BRL     _structval_L37
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_structval_L37
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img1
_structval_L40
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #2
                BVC     _structval_L43
                EOR     #$8000
_structval_L43
                BMI     *+5
                BRL     _structval_L42
                INC     _fcc_img0
_structval_L41
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                INC
                INC
                STA     _fcc_fpr1
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDY     #4
_structval_L44
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structval_L44
                LDA     _fcc_fpr0
                BRL     _structval_L40
_structval_L42
                LDA     _fcc_img0
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_img1
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #2
                BEQ     *+5
                BRL     _structval_L46
                LDA     #42
                PHA
                LDA     #41
                PHA
                LDA     #40
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L46
                LDA     #1
                BRL     _structval_L47
_structval_L46
                LDA     #0
_structval_L47
                CMP     #0
                BNE     *+5
                BRL     _structval_L45
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_structval_L45
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
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
                CLC
                ADC     #2
                STA     _fcc_fpr1
                LDY     #4
_structval_L48
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structval_L48
                LDA     #32
                PHA
                LDA     #31
                PHA
                LDA     #30
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
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
                CLC
                ADC     #8
                STA     _fcc_fpr1
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDY     #4
_structval_L49
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structval_L49
                LDA     #35
                PHA
                LDA     #34
                PHA
                LDA     #33
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BEQ     _structval_L52
                LDA     #0
                BRA     _structval_L53
_structval_L52
                LDA     #1
_structval_L53
                CMP     #0
                BNE     *+5
                BRL     _structval_L50
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #_structval_gp
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr1],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #2
                STA     _fcc_fpr1
                BRL     _structval_L51
_structval_L50
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
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
                CLC
                ADC     #2
                STA     _fcc_fpr1
_structval_L51
                LDY     #4
_structval_L54
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structval_L54
                FGX2_FARCALL mk
                LDA     #0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     #7
                STA     [_fcc_fpr0]
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BNE     *+5
                BRL     _structval_L60
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #0
                BNE     *+5
                BRL     _structval_L60
                LDA     #1
                BRL     _structval_L61
_structval_L60
                LDA     #0
_structval_L61
                CMP     #0
                BNE     *+5
                BRL     _structval_L58
                LDA     #32
                PHA
                LDA     #31
                PHA
                LDA     #30
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_sv
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L58
                LDA     #1
                BRL     _structval_L59
_structval_L58
                LDA     #0
_structval_L59
                CMP     #0
                BNE     *+5
                BRL     _structval_L56
                LDA     _structval_g2+20
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _structval_L56
                LDA     #1
                BRL     _structval_L57
_structval_L56
                LDA     #0
_structval_L57
                CMP     #0
                BNE     *+5
                BRL     _structval_L55
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_structval_L55
                LDA     #12
                PHA
                LDA     #11
                PHA
                LDA     #10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g0
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L69
                LDA     #25
                PHA
                LDA     #24
                PHA
                LDA     #23
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_g1
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L69
                LDA     #1
                BRL     _structval_L70
_structval_L69
                LDA     #0
_structval_L70
                CMP     #0
                BNE     *+5
                BRL     _structval_L67
                LDA     #42
                PHA
                LDA     #41
                PHA
                LDA     #40
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_structval_gvs
                STA     _fcc_fpr0
                LDA     #1
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structval_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _structval_L67
                LDA     #1
                BRL     _structval_L68
_structval_L67
                LDA     #0
_structval_L68
                CMP     #0
                BNE     *+5
                BRL     _structval_L65
                LDA     _structval_g0+0
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _structval_L65
                LDA     #1
                BRL     _structval_L66
_structval_L65
                LDA     #0
_structval_L66
                CMP     #0
                BNE     *+5
                BRL     _structval_L63
                LDA     _structval_g0+20
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _structval_L63
                LDA     #1
                BRL     _structval_L64
_structval_L63
                LDA     #0
_structval_L64
                CMP     #0
                BNE     *+5
                BRL     _structval_L62
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CLC
                ADC     #6
                STA     7,S   ; fccstk d=0 b=7
_structval_L62
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 35
