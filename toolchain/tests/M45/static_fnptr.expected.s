                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_fnptr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT seven
seven            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #seven_FRAMESIZE
                DO      seven_STKGUARD
                BCC     seven_stkovf
                CMP     _fcc_stkfloor
                BCS     seven_stkok
seven_stkovf       JMP     _fcc_stkoflow
                FIN
seven_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #seven_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
seven_FRAMESIZE   EQU     0
seven_STKGUARD    EQU     0
                FGX2_EXPORT thirty
thirty            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #thirty_FRAMESIZE
                DO      thirty_STKGUARD
                BCC     thirty_stkovf
                CMP     _fcc_stkfloor
                BCS     thirty_stkok
thirty_stkovf       JMP     _fcc_stkoflow
                FIN
thirty_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #thirty_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
thirty_FRAMESIZE   EQU     0
thirty_STKGUARD    EQU     0
                FGX2_EXPORT five
five            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #five_FRAMESIZE
                DO      five_STKGUARD
                BCC     five_stkovf
                CMP     _fcc_stkfloor
                BCS     five_stkok
five_stkovf       JMP     _fcc_stkoflow
                FIN
five_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #five_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
five_FRAMESIZE   EQU     0
five_STKGUARD    EQU     0
                FGX2_EXPORT keep
keep            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #keep_FRAMESIZE
                DO      keep_STKGUARD
                BCC     keep_stkovf
                CMP     _fcc_stkfloor
                BCS     keep_stkok
keep_stkovf       JMP     _fcc_stkoflow
                FIN
keep_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+keep_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+keep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+keep_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #0
                BEQ     _static_fnptr_L0
                SEP     #$20
                MX      %10
                LDA     _static_fnptr_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _static_fnptr_FA1
                STA     keep_sl_a
                LDA     _fcc_fpr0+2
                STA     keep_sl_a+2
                SEP     #$20
                MX      %10
                LDA     _static_fnptr_FA2+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _static_fnptr_FA2
                STA     _fcc_fpr0
                STA     keep_sl_b
                LDA     _fcc_fpr0+2
                STA     keep_sl_b+2
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #keep_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_static_fnptr_L0
                SEP     #$20
                MX      %10
                LDA     keep_sl_a+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     keep_sl_a
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _static_fnptr_L3-1
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
_static_fnptr_L3
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     keep_sl_b+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     keep_sl_b
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _static_fnptr_L4-1
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
_static_fnptr_L4
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
                PHA
                SEP     #$20
                MX      %10
                LDA     keep_sl_c+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     keep_sl_c
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _static_fnptr_L5-1
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
_static_fnptr_L5
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
                TAY
                TSC
                CLC
                ADC     #keep_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
keep_FRAMESIZE   EQU     0
keep_STKGUARD    EQU     1
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
                LDA     #1
                PHA
                FGX2_FARCALL keep
                PLY
                LDA     #0
                PHA
                FGX2_FARCALL keep
                PLY
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
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
