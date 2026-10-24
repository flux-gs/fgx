                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_drift.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add_b
add_b            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add_b_FRAMESIZE
                DO      add_b_STKGUARD
                BCC     add_b_stkovf
                CMP     _fcc_stkfloor
                BCS     add_b_stkok
add_b_stkovf       JMP     _fcc_stkoflow
                FIN
add_b_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add_b_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add_b_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add_b_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #20
                TAY
                TSC
                CLC
                ADC     #add_b_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add_b_FRAMESIZE   EQU     0
add_b_STKGUARD    EQU     0
                FGX2_EXPORT add_c
add_c            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add_c_FRAMESIZE
                DO      add_c_STKGUARD
                BCC     add_c_stkovf
                CMP     _fcc_stkfloor
                BCS     add_c_stkok
add_c_stkovf       JMP     _fcc_stkoflow
                FIN
add_c_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add_c_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add_c_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add_c_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                CLC
                ADC     #30
                TAY
                TSC
                CLC
                ADC     #add_c_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add_c_FRAMESIZE   EQU     0
add_c_STKGUARD    EQU     0
                FGX2_EXPORT add_a
add_a            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add_a_FRAMESIZE
                DO      add_a_STKGUARD
                BCC     add_a_stkovf
                CMP     _fcc_stkfloor
                BCS     add_a_stkok
add_a_stkovf       JMP     _fcc_stkoflow
                FIN
add_a_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add_a_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add_a_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add_a_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                INC
                INC
                TAY
                TSC
                CLC
                ADC     #add_a_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add_a_FRAMESIZE   EQU     0
add_a_STKGUARD    EQU     0
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
                CLC
                ADC     #0
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
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #40
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_drift_L0-1
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
_fnptr_drift_L0
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
                FGX2_RELOC_COUNT 5
