                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fprhold.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT same
same            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #same_FRAMESIZE
                DO      same_STKGUARD
                BCC     same_stkovf
                CMP     _fcc_stkfloor
                BCS     same_stkok
same_stkovf       JMP     _fcc_stkoflow
                FIN
same_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
same_FRAMESIZE   EQU     0
same_STKGUARD    EQU     0
                FGX2_EXPORT move
move            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #move_FRAMESIZE
                DO      move_STKGUARD
                BCC     move_stkovf
                CMP     _fcc_stkfloor
                BCS     move_stkok
move_stkovf       JMP     _fcc_stkoflow
                FIN
move_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+move_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+move_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+move_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+move_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+move_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+move_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #x+24
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #move_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
move_FRAMESIZE   EQU     0
move_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #main_FRAMESIZE-8
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
                STA     _fcc_img18
_fprhold_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                SEC
                SBC     #4
                BVC     _fprhold_L3
                EOR     #$8000
_fprhold_L3
                BMI     *+5
                BRL     _fprhold_L2
                LDA     _fcc_img18
                ASL
                ASL
                ASL
                CLC
                ADC     #x
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img18
                INC
                STA     [_fcc_fpr0]
                LDA     _fcc_img18
                ASL
                ASL
                ASL
                CLC
                ADC     #x
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img18
                INC
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img18
                ASL
                ASL
                ASL
                CLC
                ADC     #x
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img18
                TAX
                SEC
                SBC     #3
                BVC     _fprhold_L6
                EOR     #$8000
_fprhold_L6
                BPL     _fprhold_L4
                LDA     _fcc_img18
                TAX
                INC
                ASL
                ASL
                ASL
                CLC
                ADC     #x
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                BRA     _fprhold_L5
_fprhold_L4
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
_fprhold_L5
                LDA     _fcc_fpr1
                LDY     #4
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #6
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
_fprhold_L1
                INC     _fcc_img18
                BRL     _fprhold_L0
_fprhold_L2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     [_fcc_fpr0]
                STA     _fcc_img19
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_img19
                PHA
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                TAX
                CMP     #3
                BEQ     _fprhold_L7
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_fprhold_L7
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #3
                BNE     _fprhold_L9
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #30
                BEQ     _fprhold_L8
_fprhold_L9
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_fprhold_L8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
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
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_img19
                LDA     _fcc_img16
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #x+16
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_img16]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_img16],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img19
                PHA
                LDA     13,S   ; fccstk d=2 b=11
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=2 b=9
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                TAX
                CMP     #4
                BEQ     _fprhold_L10
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_fprhold_L10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x+8
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_img19
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL move
                PLY
                PLY
                LDA     _fcc_img19
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                TAX
                CMP     #6
                BEQ     _fprhold_L11
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_fprhold_L11
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x
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
                LDA     #x+24
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                TAX
                CMP     #15
                BEQ     _fprhold_L12
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_fprhold_L12
                LDA     #0
                STA     _fcc_img19
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_fprhold_L13
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _fprhold_L15
                LDA     _fcc_img19
                PHA
                LDA     [_fcc_fpr0]
                LDX     #2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _fprhold_L18
                EOR     #$8000
_fprhold_L18
                BPL     _fprhold_L16
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BRA     _fprhold_L17
_fprhold_L16
                LDA     [_fcc_fpr0]
_fprhold_L17
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
_fprhold_L14
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                BRA     _fprhold_L13
_fprhold_L15
                LDA     _fcc_img19
                TAX
                CMP     #73
                BEQ     _fprhold_L19
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_fprhold_L19
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x+8
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                LDA     [_fcc_fpr0]
                STA     _fcc_img19
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     #9
                STA     [_fcc_fpr0]
                LDA     _fcc_img19
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                TAX
                CMP     #11
                BEQ     _fprhold_L20
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRA     main_bandx
_fprhold_L20
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x+16
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL same
                PLY
                PLY
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                TAX
                CMP     #33
                BEQ     _fprhold_L21
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRA     main_bandx
_fprhold_L21
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
main_bandx
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
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
