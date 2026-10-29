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
                STA     _fcc_img0
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
                STA     _fcc_img1
                LDA     _fcc_img0
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
                STA     [_fcc_img0]
                LDA     _fcc_img0
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
                INC
                LDY     #2
                STA     [_fcc_img0],Y
                LDA     _fcc_img0
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
                INC
                INC
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #4
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
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
                TAX
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
                STA     _fcc_img0
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
                STA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
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
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
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
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
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
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                TSC
                SEC
                SBC     #main_FRAMESIZE-10
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
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
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
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
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
                PLY
                PLY
                PLY
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
                PLY
                PLY
                PLY
                LDA     #0
                STA     _fcc_img20
_structsrcdeep_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img20
                TAX
                SEC
                SBC     #3
                BVC     _structsrcdeep_L7
                EOR     #$8000
_structsrcdeep_L7
                BMI     *+5
                BRL     _structsrcdeep_L6
                LDA     _fcc_img20
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
                ADC     _fcc_img20
                STA     [_fcc_fpr0]
                LDA     _fcc_img20
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
                ADC     _fcc_img20
                STA     [_fcc_fpr0]
                LDA     #300
                PHA
                LDA     _fcc_img20
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
                LDA     _fcc_img20
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
                ADC     #2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _structsrcdeep_fill
                PLY
                PLY
                PLY
_structsrcdeep_L5
                INC     _fcc_img20
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
                PLY
                PLY
                PLY
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
                PLY
                PLY
                PLY
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
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L9
                LDA     17,S   ; fccstk d=0 b=17
                TAX
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
                PLY
                PLY
                PLY
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L11
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L11
                LDA     #2
                STA     _fcc_img20
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
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
                CLC
                ADC     #18
                STA     _fcc_fpr1
                LDA     _fcc_img20
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
                CMP     #13058
                BNE     _structsrcdeep_L13
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                CMP     #17410
                BNE     _structsrcdeep_L13
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L13
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L13
                LDA     #0
                STA     _fcc_img20
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
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
                CLC
                ADC     #18
                STA     _fcc_fpr1
                LDA     _fcc_img20
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
_structsrcdeep_L14
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L14
                LDA     19,S   ; fccstk d=0 b=19
                TAX
                CMP     #13056
                BNE     _structsrcdeep_L15
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                CMP     #17408
                BNE     _structsrcdeep_L15
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L15
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L15
                LDA     #1
                STA     _fcc_img20
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
                PLY
                PLY
                PLY
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
                LDA     _fcc_img17
                STA     _fcc_fpr1+2
                LDA     _fcc_img16
                CLC
                ADC     #18
                STA     _fcc_fpr1
                LDA     _fcc_img20
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
_structsrcdeep_L16
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L16
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L17
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L17
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
                LDA     [_fcc_img18]
                PHA
                LDY     #2
                LDA     [_fcc_img18],Y
                STA     _fcc_fpr1+2
                PLA
                CLC
                ADC     #2
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
                CMP     #4369
                BNE     _structsrcdeep_L19
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                CMP     #8738
                BNE     _structsrcdeep_L19
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L19
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L19
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
_structsrcdeep_L20
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _structsrcdeep_L20
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L21
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
                PLY
                PLY
                PLY
                CMP     #0
                BEQ     _structsrcdeep_L21
                LDA     gt+2
                TAX
                CMP     #4369
                BNE     _structsrcdeep_L21
                LDA     gt+0
                TAX
                CMP     #30583
                BNE     _structsrcdeep_L21
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #6
                STA     17,S   ; fccstk d=0 b=17
_structsrcdeep_L21
                LDA     17,S   ; fccstk d=0 b=17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-10
                TCS
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
main_FRAMESIZE   EQU     38
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 19
