                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fp_array.c
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
                FGX2_EXPORT add_ten
add_ten            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add_ten_FRAMESIZE
                DO      add_ten_STKGUARD
                BCC     add_ten_stkovf
                CMP     _fcc_stkfloor
                BCS     add_ten_stkok
add_ten_stkovf       JMP     _fcc_stkoflow
                FIN
add_ten_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add_ten_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add_ten_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add_ten_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #10
                TAY
                TSC
                CLC
                ADC     #add_ten_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add_ten_FRAMESIZE   EQU     0
add_ten_STKGUARD    EQU     0
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
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    conv+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    conv,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #3
                PHA
                LDA     _fcc_fpr0
                PHK
                PEA     _fp_array_L0-1
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
_fp_array_L0
                TAY
                PLA
                TYA
                STA     5,S   ; fccstk d=0 b=5
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    conv+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    conv,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #4
                PHA
                LDA     _fcc_fpr0
                PHK
                PEA     _fp_array_L1-1
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
_fp_array_L1
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     #2
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    conv+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    conv,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #14
                PHA
                LDA     _fcc_fpr0
                PHK
                PEA     _fp_array_L2-1
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
_fp_array_L2
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 5
