                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_struct.c
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
                TAX
                DO      6+seven_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+seven_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+seven_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
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
                LDA     _fn_struct_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fn_struct_FA0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_ptr+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     #35
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PHK
                PEA     _fn_struct_L1-1
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
_fn_struct_L1
                TAY
                PLA
                TYA
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
