                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from voidcomma.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT clear
clear            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #clear_FRAMESIZE
                DO      clear_STKGUARD
                BCC     clear_stkovf
                CMP     _fcc_stkfloor
                BCS     clear_stkok
clear_stkovf       JMP     _fcc_stkoflow
                FIN
clear_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+clear_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+clear_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+clear_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+clear_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+clear_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+clear_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #clear_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
clear_FRAMESIZE   EQU     0
clear_STKGUARD    EQU     0
                FGX2_EXPORT step
step            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #step_FRAMESIZE
                DO      step_STKGUARD
                BCC     step_stkovf
                CMP     _fcc_stkfloor
                BCS     step_stkok
step_stkovf       JMP     _fcc_stkoflow
                FIN
step_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+step_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+step_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+step_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+step_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+step_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+step_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL clear
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                DO      8+step_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+step_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+step_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+step_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+step_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+step_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #5
                STA     [_fcc_fpr0]
                DO      6+step_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+step_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+step_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+step_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+step_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+step_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                STA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #step_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
step_FRAMESIZE   EQU     2
step_STKGUARD    EQU     0
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
                LDA     #99
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL step
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _voidcomma_L0
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
_voidcomma_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #sink
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL clear
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #7
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL clear
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #20
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
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
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
