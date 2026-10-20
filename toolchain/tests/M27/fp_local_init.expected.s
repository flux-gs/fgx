                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fp_local_init.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT double_it
double_it            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #double_it_FRAMESIZE
                DO      double_it_STKGUARD
                BCC     double_it_stkovf
                CMP     _fcc_stkfloor
                BCS     double_it_stkok
double_it_stkovf       JMP     _fcc_stkoflow
                FIN
double_it_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+double_it_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+double_it_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+double_it_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                TAY
                TSC
                CLC
                ADC     #double_it_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
double_it_FRAMESIZE   EQU     0
double_it_STKGUARD    EQU     0
                FGX2_EXPORT triple_it
triple_it            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #triple_it_FRAMESIZE
                DO      triple_it_STKGUARD
                BCC     triple_it_stkovf
                CMP     _fcc_stkfloor
                BCS     triple_it_stkok
triple_it_stkovf       JMP     _fcc_stkoflow
                FIN
triple_it_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+triple_it_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+triple_it_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+triple_it_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #triple_it_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
triple_it_FRAMESIZE   EQU     0
triple_it_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     _fp_local_init_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fp_local_init_FA0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     _fp_local_init_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fp_local_init_FA1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #6
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PHK
                PEA     _fp_local_init_L2-1
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
_fp_local_init_L2
                TAY
                PLA
                TYA
                PHA
                LDA     #10
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PHK
                PEA     _fp_local_init_L3-1
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
_fp_local_init_L3
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 4
