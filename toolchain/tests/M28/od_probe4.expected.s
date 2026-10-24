                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from od_probe4.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sink
sink            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sink_FRAMESIZE
                DO      sink_STKGUARD
                BCC     sink_stkovf
                CMP     _fcc_stkfloor
                BCS     sink_stkok
sink_stkovf       JMP     _fcc_stkoflow
                FIN
sink_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+sink_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sink_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sink_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+sink_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sink_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sink_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+sink_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sink_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sink_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      14+sink_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+sink_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+sink_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      16+sink_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+sink_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+sink_FRAMESIZE,S   ; fccstk d=2 b=14 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sink_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sink_FRAMESIZE   EQU     0
sink_STKGUARD    EQU     0
                FGX2_EXPORT put1
put1            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #put1_FRAMESIZE
                DO      put1_STKGUARD
                BCC     put1_stkovf
                CMP     _fcc_stkfloor
                BCS     put1_stkok
put1_stkovf       JMP     _fcc_stkoflow
                FIN
put1_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+put1_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+put1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+put1_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+put1_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+put1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+put1_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                DO      12+put1_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+put1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+put1_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+put1_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+put1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+put1_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                STA     _fcc_ptr
                LDA     9,S   ; fccstk d=6 b=3
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL sink
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                PHA
                DO      14+put1_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+put1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+put1_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+put1_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+put1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+put1_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #put1_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
put1_FRAMESIZE   EQU     6
put1_STKGUARD    EQU     0
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
                LDY     #6
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
                LDA     #data
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #data
                PHA
                LDA     #1
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
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #vec
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
                LDA     #vec
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
                LDA     #0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #data
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=8 b=9
                STA     _fcc_fpr0
                PHK
                PEA     _od_probe4_L0-1
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
_od_probe4_L0
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CLC
                ADC     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 7
