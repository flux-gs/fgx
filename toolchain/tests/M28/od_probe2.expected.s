                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from od_probe2.c
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
                STA     _fcc_img0
                DO      10+f2_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+f2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+f2_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
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
                LDA     [_fcc_img0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDY     #2
                LDA     [_fcc_img0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     g_result
                LDA     #0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #5
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=6 b=1
                STA     _fcc_fpr0
                PHK
                PEA     _od_probe2_L0-1
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
_od_probe2_L0
                TSC
                CLC
                ADC     #6
                TCS
                LDA     g_result
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 3
