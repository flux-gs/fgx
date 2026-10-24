                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from od_probe3.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT getput
getput            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getput_FRAMESIZE
                DO      getput_STKGUARD
                BCC     getput_stkovf
                CMP     _fcc_stkfloor
                BCS     getput_stkok
getput_stkovf       JMP     _fcc_stkoflow
                FIN
getput_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+getput_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+getput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+getput_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+getput_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+getput_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+getput_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #getput_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getput_FRAMESIZE   EQU     0
getput_STKGUARD    EQU     0
                FGX2_EXPORT setit
setit            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #setit_FRAMESIZE
                DO      setit_STKGUARD
                BCC     setit_stkovf
                CMP     _fcc_stkfloor
                BCS     setit_stkok
setit_stkovf       JMP     _fcc_stkoflow
                FIN
setit_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+setit_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+setit_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+setit_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                DO      12+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+setit_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                DO      14+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+setit_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_fpr0
                DO      16+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+setit_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                LDY     #10
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #setit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
setit_FRAMESIZE   EQU     0
setit_STKGUARD    EQU     0
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
                PHA
                LDA     #8
                PHA
                LDA     #2
                PHA
                LDA     #6
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL setit
                TSC
                CLC
                ADC     #12
                TCS
                LDA     a+0
                TAX
                CMP     #6
                BEQ     _od_probe3_L0
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
_od_probe3_L0
                LDA     a+2
                TAX
                CMP     #2
                BEQ     _od_probe3_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_od_probe3_L1
                LDA     a+4
                TAX
                CMP     #8
                BEQ     _od_probe3_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_od_probe3_L2
                LDA     a+10
                BEQ     _od_probe3_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_od_probe3_L3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vec
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
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
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #vec
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_ptr
                LDA     3,S   ; fccstk d=0 b=3
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
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _od_probe3_L5
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _od_probe3_L5
                LDA     #0
                BRA     _od_probe3_L6
_od_probe3_L5
                LDA     #1
_od_probe3_L6
                CMP     #0
                BEQ     _od_probe3_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_od_probe3_L4
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #6
                BEQ     _od_probe3_L7
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_od_probe3_L7
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #8
                BEQ     _od_probe3_L8
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_od_probe3_L8
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tbl+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tbl,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
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
                ADC     #12
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=8 b=9
                STA     _fcc_fpr0
                PHK
                PEA     _od_probe3_L10-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_od_probe3_L10
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #16
                BEQ     _od_probe3_L9
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_od_probe3_L9
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
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 5
