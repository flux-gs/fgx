                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from od_probe.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f2
f2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f2_FRAMESIZE
                DO      f2_STKGUARD
                BCC     f2_stkovf
                CMP     _fcc_stkfloor
                BCS     f2_stkok
f2_stkovf       JMP     _fcc_stkoflow
                FIN
f2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                DO      14+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+f2_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+f2_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      14+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+f2_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+f2_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      14+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+f2_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+f2_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #f2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f2_FRAMESIZE   EQU     0
f2_STKGUARD    EQU     0
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
                LDA     #gbuf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #5
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
                LDA     #10
                STA     gs+0
                LDA     #20
                STA     gs+2
                LDA     #7
                STA     gs+4
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
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
                LDA     #gbuf
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=8 b=1
                STA     _fcc_fpr0
                PHK
                PEA     _od_probe_L0-1
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
_od_probe_L0
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
