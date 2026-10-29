                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_table.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add5
add5            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add5_FRAMESIZE
                DO      add5_STKGUARD
                BCC     add5_stkovf
                CMP     _fcc_stkfloor
                BCS     add5_stkok
add5_stkovf       JMP     _fcc_stkoflow
                FIN
add5_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add5_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add5_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add5_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CLC
                ADC     #5
                TAY
                TSC
                CLC
                ADC     #add5_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add5_FRAMESIZE   EQU     0
add5_STKGUARD    EQU     0
                FGX2_EXPORT add37
add37            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add37_FRAMESIZE
                DO      add37_STKGUARD
                BCC     add37_stkovf
                CMP     _fcc_stkfloor
                BCS     add37_stkok
add37_stkovf       JMP     _fcc_stkoflow
                FIN
add37_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add37_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add37_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add37_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CLC
                ADC     #37
                TAY
                TSC
                CLC
                ADC     #add37_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add37_FRAMESIZE   EQU     0
add37_STKGUARD    EQU     0
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
                ASL
                ASL
                ASL
                CLC
                ADC     #tbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #5
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_table_L0-1
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
_fnptr_table_L0
                TAY
                TSC
                CLC
                ADC     #6
                TCS
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 4
