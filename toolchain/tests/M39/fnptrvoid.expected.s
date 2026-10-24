                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptrvoid.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _fnptrvoid_f0
_fnptrvoid_f0            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptrvoid_f0_FRAMESIZE
                DO      _fnptrvoid_f0_STKGUARD
                BCC     _fnptrvoid_f0_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptrvoid_f0_stkok
_fnptrvoid_f0_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptrvoid_f0_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _fnptrvoid_hits
                TAX
                TXA
                INC
                STA     _fnptrvoid_hits
                TAY
                TSC
                CLC
                ADC     #_fnptrvoid_f0_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptrvoid_f0_FRAMESIZE   EQU     0
_fnptrvoid_f0_STKGUARD    EQU     0
                FGX2_EXPORT _fnptrvoid_f1
_fnptrvoid_f1            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptrvoid_f1_FRAMESIZE
                DO      _fnptrvoid_f1_STKGUARD
                BCC     _fnptrvoid_f1_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptrvoid_f1_stkok
_fnptrvoid_f1_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptrvoid_f1_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _fnptrvoid_hits
                TAX
                TXA
                CLC
                ADC     #40
                STA     _fnptrvoid_hits
                TAY
                TSC
                CLC
                ADC     #_fnptrvoid_f1_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptrvoid_f1_FRAMESIZE   EQU     0
_fnptrvoid_f1_STKGUARD    EQU     0
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
                STA     _fnptrvoid_hits
                LDA     #0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tab+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tab,X
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptrvoid_L0-1
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
_fnptrvoid_L0
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
_fnptrvoid_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #2
                BVC     _fnptrvoid_L4
                EOR     #$8000
_fnptrvoid_L4
                BPL     _fnptrvoid_L3
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tab+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tab,X
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptrvoid_L5-1
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
_fnptrvoid_L5
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
_fnptrvoid_L2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRA     _fnptrvoid_L1
_fnptrvoid_L3
                LDA     #0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tab+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tab,X
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptrvoid_L6-1
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
_fnptrvoid_L6
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fnptrvoid_hits
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 4
