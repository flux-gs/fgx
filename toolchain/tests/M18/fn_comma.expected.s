                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_comma.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add10
add10            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add10_FRAMESIZE
                DO      add10_STKGUARD
                BCC     add10_stkovf
                CMP     _fcc_stkfloor
                BCS     add10_stkok
add10_stkovf       JMP     _fcc_stkoflow
                FIN
add10_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #add10_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add10_FRAMESIZE   EQU     0
add10_STKGUARD    EQU     0
                FGX2_EXPORT add32
add32            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add32_FRAMESIZE
                DO      add32_STKGUARD
                BCC     add32_stkovf
                CMP     _fcc_stkfloor
                BCS     add32_stkok
add32_stkovf       JMP     _fcc_stkoflow
                FIN
add32_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #add32_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add32_FRAMESIZE   EQU     0
add32_STKGUARD    EQU     0
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
                LDA     _fn_comma_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fn_comma_FA0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     _fn_comma_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fn_comma_FA1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PHK
                PEA     _fn_comma_L2-1
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
_fn_comma_L2
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0
                PHK
                PEA     _fn_comma_L3-1
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
_fn_comma_L3
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
