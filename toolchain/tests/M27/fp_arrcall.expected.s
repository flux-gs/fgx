                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fp_arrcall.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT dbl
dbl            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dbl_FRAMESIZE
                DO      dbl_STKGUARD
                BCC     dbl_stkovf
                CMP     _fcc_stkfloor
                BCS     dbl_stkok
dbl_stkovf       JMP     _fcc_stkoflow
                FIN
dbl_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+dbl_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dbl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dbl_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                TAY
                TSC
                CLC
                ADC     #dbl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dbl_FRAMESIZE   EQU     0
dbl_STKGUARD    EQU     0
                FGX2_EXPORT trp
trp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #trp_FRAMESIZE
                DO      trp_STKGUARD
                BCC     trp_stkovf
                CMP     _fcc_stkfloor
                BCS     trp_stkok
trp_stkovf       JMP     _fcc_stkoflow
                FIN
trp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+trp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+trp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+trp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #trp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
trp_FRAMESIZE   EQU     0
trp_STKGUARD    EQU     0
                FGX2_EXPORT add4
add4            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add4_FRAMESIZE
                DO      add4_STKGUARD
                BCC     add4_stkovf
                CMP     _fcc_stkfloor
                BCS     add4_stkok
add4_stkovf       JMP     _fcc_stkoflow
                FIN
add4_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add4_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add4_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add4_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #add4_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add4_FRAMESIZE   EQU     0
add4_STKGUARD    EQU     0
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
                LDA     #20
                STA     5,S   ; fccstk d=0 b=5
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fp_arrcall_L0-1
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
_fp_arrcall_L0
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #4
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fp_arrcall_L1-1
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
_fp_arrcall_L1
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     #2
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=6 b=5
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fp_arrcall_L2-1
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
_fp_arrcall_L2
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
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
