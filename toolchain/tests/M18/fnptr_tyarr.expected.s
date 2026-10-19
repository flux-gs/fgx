                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_tyarr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _fnptr_tyarr_f0
_fnptr_tyarr_f0            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_tyarr_f0_FRAMESIZE
                DO      _fnptr_tyarr_f0_STKGUARD
                BCC     _fnptr_tyarr_f0_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_tyarr_f0_stkok
_fnptr_tyarr_f0_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_tyarr_f0_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #_fnptr_tyarr_f0_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_tyarr_f0_FRAMESIZE   EQU     0
_fnptr_tyarr_f0_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_tyarr_f1
_fnptr_tyarr_f1            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_tyarr_f1_FRAMESIZE
                DO      _fnptr_tyarr_f1_STKGUARD
                BCC     _fnptr_tyarr_f1_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_tyarr_f1_stkok
_fnptr_tyarr_f1_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_tyarr_f1_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #_fnptr_tyarr_f1_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_tyarr_f1_FRAMESIZE   EQU     0
_fnptr_tyarr_f1_STKGUARD    EQU     0
                FGX2_EXPORT _fnptr_tyarr_f2
_fnptr_tyarr_f2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fnptr_tyarr_f2_FRAMESIZE
                DO      _fnptr_tyarr_f2_STKGUARD
                BCC     _fnptr_tyarr_f2_stkovf
                CMP     _fcc_stkfloor
                BCS     _fnptr_tyarr_f2_stkok
_fnptr_tyarr_f2_stkovf       JMP     _fcc_stkoflow
                FIN
_fnptr_tyarr_f2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #_fnptr_tyarr_f2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_tyarr_f2_FRAMESIZE   EQU     0
_fnptr_tyarr_f2_STKGUARD    EQU     0
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
                LDA:    Tbl+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    Tbl,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    Tbl+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    Tbl,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    Tbl2+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    Tbl2,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PHK
                PEA     _fnptr_tyarr_L0-1
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
_fnptr_tyarr_L0
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0
                PHK
                PEA     _fnptr_tyarr_L1-1
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
_fnptr_tyarr_L1
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     13,S   ; fccstk d=2 b=11
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=2 b=9
                STA     _fcc_fpr0
                PHK
                PEA     _fnptr_tyarr_L2-1
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
_fnptr_tyarr_L2
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 5
