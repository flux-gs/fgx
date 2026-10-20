                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from g_fp_init.c
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
                LDA     #6
                PHA
                SEP     #$20
                MX      %10
                LDA     gh+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gh
                STA     _fcc_fpr0
                PHK
                PEA     _g_fp_init_L0-1
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
_g_fp_init_L0
                TAY
                PLA
                TYA
                PHA
                LDA     #10
                PHA
                SEP     #$20
                MX      %10
                LDA     gh2+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gh2
                STA     _fcc_fpr0
                PHK
                PEA     _g_fp_init_L1-1
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
_g_fp_init_L1
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 4
