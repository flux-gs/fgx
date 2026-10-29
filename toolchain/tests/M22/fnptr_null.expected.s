                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_null.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add40
add40            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add40_FRAMESIZE
                DO      add40_STKGUARD
                BCC     add40_stkovf
                CMP     _fcc_stkfloor
                BCS     add40_stkok
add40_stkovf       JMP     _fcc_stkoflow
                FIN
add40_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add40_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add40_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add40_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                CLC
                ADC     #40
                TAY
                TSC
                CLC
                ADC     #add40_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add40_FRAMESIZE   EQU     0
add40_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _fnptr_null_L2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _fnptr_null_L2
                LDA     #0
                BRA     _fnptr_null_L3
_fnptr_null_L2
                LDA     #1
_fnptr_null_L3
                CMP     #0
                BEQ     *+5
                BRL     _fnptr_null_L1
                LDA     #0
                ASL
                CLC
                ADC     #0
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
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _fnptr_null_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _fnptr_null_L4
                LDA     #0
                BRA     _fnptr_null_L5
_fnptr_null_L4
                LDA     #1
_fnptr_null_L5
                CMP     #0
                BNE     _fnptr_null_L1
                LDA     #1
                ASL
                INC
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
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _fnptr_null_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _fnptr_null_L6
                LDA     #0
                BRA     _fnptr_null_L7
_fnptr_null_L6
                LDA     #1
_fnptr_null_L7
                CMP     #0
                BEQ     _fnptr_null_L0
_fnptr_null_L1
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fnptr_null_L0
                LDA     #1
                ASL
                INC
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
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_null_L8-1
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
_fnptr_null_L8
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
                FGX2_RELOC_COUNT 3
