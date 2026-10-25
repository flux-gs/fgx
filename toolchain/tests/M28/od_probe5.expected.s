                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from od_probe5.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT helper_a
helper_a            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #helper_a_FRAMESIZE
                DO      helper_a_STKGUARD
                BCC     helper_a_stkovf
                CMP     _fcc_stkfloor
                BCS     helper_a_stkok
helper_a_stkovf       JMP     _fcc_stkoflow
                FIN
helper_a_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #helper_a_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
helper_a_FRAMESIZE   EQU     0
helper_a_STKGUARD    EQU     0
                FGX2_EXPORT helper_b
helper_b            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #helper_b_FRAMESIZE
                DO      helper_b_STKGUARD
                BCC     helper_b_stkovf
                CMP     _fcc_stkfloor
                BCS     helper_b_stkok
helper_b_stkovf       JMP     _fcc_stkoflow
                FIN
helper_b_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #helper_b_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
helper_b_FRAMESIZE   EQU     0
helper_b_STKGUARD    EQU     0
                FGX2_EXPORT f0
f0            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f0_FRAMESIZE
                DO      f0_STKGUARD
                BCC     f0_stkovf
                CMP     _fcc_stkfloor
                BCS     f0_stkok
f0_stkovf       JMP     _fcc_stkoflow
                FIN
f0_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+f0_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f0_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f0_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CLC
                ADC     #0
                TAY
                TSC
                CLC
                ADC     #f0_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f0_FRAMESIZE   EQU     0
f0_STKGUARD    EQU     0
                FGX2_EXPORT f1
f1            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f1_FRAMESIZE
                DO      f1_STKGUARD
                BCC     f1_stkovf
                CMP     _fcc_stkfloor
                BCS     f1_stkok
f1_stkovf       JMP     _fcc_stkoflow
                FIN
f1_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+f1_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f1_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CLC
                ADC     #10
                TAY
                TSC
                CLC
                ADC     #f1_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f1_FRAMESIZE   EQU     0
f1_STKGUARD    EQU     0
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
                TAX
                CLC
                ADC     #20
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
                FGX2_EXPORT f3
f3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f3_FRAMESIZE
                DO      f3_STKGUARD
                BCC     f3_stkovf
                CMP     _fcc_stkfloor
                BCS     f3_stkok
f3_stkovf       JMP     _fcc_stkoflow
                FIN
f3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+f3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CLC
                ADC     #30
                TAY
                TSC
                CLC
                ADC     #f3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f3_FRAMESIZE   EQU     0
f3_STKGUARD    EQU     0
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
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
_od_probe5_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                SEC
                SBC     #4
                BVC     _od_probe5_L3
                EOR     #$8000
_od_probe5_L3
                BPL     _od_probe5_L2
                LDA     7,S   ; fccstk d=0 b=7
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
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                PHA
                LDA     _fcc_fpr0
                PHK
                PEA     _od_probe5_L4-1
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
_od_probe5_L4
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
_od_probe5_L1
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #1
                STA     7,S   ; fccstk d=0 b=7
                BRA     _od_probe5_L0
_od_probe5_L2
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                SEC
                SBC     #24
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
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 8
