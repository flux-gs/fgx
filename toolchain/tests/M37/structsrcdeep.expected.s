                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from structsrcdeep.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _structsrcdeep_fill
_structsrcdeep_fill            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_structsrcdeep_fill_FRAMESIZE
                DO      _structsrcdeep_fill_STKGUARD
                BCC     _structsrcdeep_fill_stkovf
                CMP     _fcc_stkfloor
                BCS     _structsrcdeep_fill_stkok
_structsrcdeep_fill_stkovf       JMP     _fcc_stkoflow
                FIN
_structsrcdeep_fill_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_structsrcdeep_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structsrcdeep_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structsrcdeep_fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structsrcdeep_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structsrcdeep_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structsrcdeep_fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+_structsrcdeep_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structsrcdeep_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structsrcdeep_fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                DO      10+_structsrcdeep_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structsrcdeep_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structsrcdeep_fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                TXA
                INC
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                DO      10+_structsrcdeep_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structsrcdeep_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structsrcdeep_fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                TXA
                INC
                INC
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DO      10+_structsrcdeep_fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_structsrcdeep_fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_structsrcdeep_fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #3
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #5
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_structsrcdeep_fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structsrcdeep_fill_FRAMESIZE   EQU     0
_structsrcdeep_fill_STKGUARD    EQU     0
                FGX2_EXPORT _structsrcdeep_same
_structsrcdeep_same            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_structsrcdeep_same_FRAMESIZE
                DO      _structsrcdeep_same_STKGUARD
                BCC     _structsrcdeep_same_stkovf
                CMP     _fcc_stkfloor
                BCS     _structsrcdeep_same_stkok
_structsrcdeep_same_stkovf       JMP     _fcc_stkoflow
                FIN
_structsrcdeep_same_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      12+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _structsrcdeep_L0
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_structsrcdeep_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structsrcdeep_L0
                DO      8+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                DO      12+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _structsrcdeep_L1
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_structsrcdeep_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structsrcdeep_L1
                DO      8+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                PHA
                DO      12+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                INC
                INC
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _structsrcdeep_L2
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_structsrcdeep_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structsrcdeep_L2
                DO      8+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #5
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                PHA
                DO      12+_structsrcdeep_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_structsrcdeep_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_structsrcdeep_same_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #3
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _structsrcdeep_L3
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_structsrcdeep_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structsrcdeep_L3
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_structsrcdeep_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_structsrcdeep_same_FRAMESIZE   EQU     0
_structsrcdeep_same_STKGUARD    EQU     0
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
                STA     17,S   ; fccstk d=0 b=17
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gh+0
                TAY
                LDA     _fcc_ptr+2
                STA     gh+2
                TYA
                LDA     #30583
                STA     gt+0
                LDA     #4369
                STA     gt+2
                LDA     #8738
                STA     gt+10
                LDA     #100
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+4
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #200
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+12
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                STA     15,S   ; fccstk d=0 b=15
_structsrcdeep_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     15,S   ; fccstk d=0 b=15
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _structsrcdeep_L7
                EOR     #$8000
_structsrcdeep_L7
                BMI     *+5
                BRL     _structsrcdeep_L6
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #gt+18
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #13056
                CLC
                ADC     15,S   ; fccstk d=0 b=15
                STA     [_fcc_fpr0]
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #gt+18
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     #17408
                CLC
                ADC     15,S   ; fccstk d=0 b=15
                STA     [_fcc_fpr0]
                LDA     #300
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #gt+18
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                TSC
                CLC
                ADC     #6
                TCS
_structsrcdeep_L5
                LDA     15,S   ; fccstk d=0 b=15
                CLC
                ADC     #1
                STA     15,S   ; fccstk d=0 b=15
                BRL     _structsrcdeep_L4
_structsrcdeep_L6
                LDA     #21845
                STA     gh+4
                LDA     #26214
                STA     gh+12
                LDA     #400
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+6
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                TSC
                CLC
                ADC     #6
                TCS
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
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                ADC     #4
                STA     _fcc_fpr1
                LDY     #4
_structsrcdeep_L8
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L8
                LDA     #100
                PHA
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
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L9
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L9
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
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gt+4
                STA     _fcc_fpr1
                PLA
                LDY     #4
_structsrcdeep_L10
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L10
                LDA     #100
                PHA
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
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L11
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L11
                LDA     #2
                STA     15,S   ; fccstk d=0 b=15
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                ADC     #18
                STA     _fcc_fpr1
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDY     #8
_structsrcdeep_L12
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L12
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CMP     #13058
                BNE     _structsrcdeep_L16
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                TXA
                CMP     #17410
                BNE     _structsrcdeep_L16
                LDA     #1
                BRA     _structsrcdeep_L17
_structsrcdeep_L16
                LDA     #0
_structsrcdeep_L17
                CMP     #0
                BEQ     _structsrcdeep_L14
                LDA     #320
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L14
                LDA     #1
                BRA     _structsrcdeep_L15
_structsrcdeep_L14
                LDA     #0
_structsrcdeep_L15
                CMP     #0
                BEQ     _structsrcdeep_L13
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L13
                LDA     #0
                STA     15,S   ; fccstk d=0 b=15
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                ADC     #18
                STA     _fcc_fpr1
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDY     #8
_structsrcdeep_L18
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L18
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CMP     #13056
                BNE     _structsrcdeep_L22
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                TXA
                CMP     #17408
                BNE     _structsrcdeep_L22
                LDA     #1
                BRA     _structsrcdeep_L23
_structsrcdeep_L22
                LDA     #0
_structsrcdeep_L23
                CMP     #0
                BEQ     _structsrcdeep_L20
                LDA     #300
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L20
                LDA     #1
                BRA     _structsrcdeep_L21
_structsrcdeep_L20
                LDA     #0
_structsrcdeep_L21
                CMP     #0
                BEQ     _structsrcdeep_L19
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L19
                LDA     #1
                STA     15,S   ; fccstk d=0 b=15
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
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                ADC     #18
                STA     _fcc_fpr1
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr1
                CLC
                ADC     #2
                STA     _fcc_fpr1
                LDY     #4
_structsrcdeep_L24
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L24
                LDA     #310
                PHA
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
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L25
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L25
                LDA     #0
                STA     19,S   ; fccstk d=0 b=19
                LDA     #0
                STA     27,S   ; fccstk d=0 b=27
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
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
                LDY     #8
_structsrcdeep_L26
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L26
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CMP     #4369
                BNE     _structsrcdeep_L30
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                TXA
                CMP     #8738
                BNE     _structsrcdeep_L30
                LDA     #1
                BRA     _structsrcdeep_L31
_structsrcdeep_L30
                LDA     #0
_structsrcdeep_L31
                CMP     #0
                BEQ     _structsrcdeep_L28
                LDA     #100
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L28
                LDA     #1
                BRA     _structsrcdeep_L29
_structsrcdeep_L28
                LDA     #0
_structsrcdeep_L29
                CMP     #0
                BEQ     _structsrcdeep_L27
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L27
                LDA     #0
                STA     gt+12
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+12
                STA     _fcc_fpr0
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #gh+6
                STA     _fcc_fpr1
                PLA
                LDY     #4
_structsrcdeep_L32
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L32
                LDA     #400
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt+12
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L38
                LDA     #400
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gh+6
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_same
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #0
                BEQ     _structsrcdeep_L38
                LDA     #1
                BRA     _structsrcdeep_L39
_structsrcdeep_L38
                LDA     #0
_structsrcdeep_L39
                CMP     #0
                BEQ     _structsrcdeep_L36
                LDA     gt+2
                TAX
                TXA
                CMP     #4369
                BNE     _structsrcdeep_L36
                LDA     #1
                BRA     _structsrcdeep_L37
_structsrcdeep_L36
                LDA     #0
_structsrcdeep_L37
                CMP     #0
                BEQ     _structsrcdeep_L34
                LDA     gt+0
                TAX
                TXA
                CMP     #30583
                BNE     _structsrcdeep_L34
                LDA     #1
                BRA     _structsrcdeep_L35
_structsrcdeep_L34
                LDA     #0
_structsrcdeep_L35
                CMP     #0
                BEQ     _structsrcdeep_L33
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L33
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 19
