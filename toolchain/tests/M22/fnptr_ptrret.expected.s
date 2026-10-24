                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_ptrret.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pick
pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pick_FRAMESIZE
                DO      pick_STKGUARD
                BCC     pick_stkovf
                CMP     _fcc_stkfloor
                BCS     pick_stkok
pick_stkovf       JMP     _fcc_stkoflow
                FIN
pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #buf
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #42
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #buf
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pick_FRAMESIZE   EQU     0
pick_STKGUARD    EQU     0
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
                LDA     _fnptr_ptrret_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fnptr_ptrret_FA0
                STA     fp
                LDA     _fcc_fpr0+2
                STA     fp+2
                SEP     #$20
                MX      %10
                LDA     fp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     fp
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptrret_L1-1
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
_fnptr_ptrret_L1
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     #buf
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _fnptr_ptrret_L3
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _fnptr_ptrret_L3
                LDA     #0
                BRL     _fnptr_ptrret_L4
_fnptr_ptrret_L3
                LDA     #1
_fnptr_ptrret_L4
                CMP     #0
                BNE     *+5
                BRL     _fnptr_ptrret_L2
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
_fnptr_ptrret_L2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
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
