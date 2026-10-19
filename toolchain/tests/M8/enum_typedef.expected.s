                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from enum_typedef.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _enum_typedef_val
_enum_typedef_val            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_enum_typedef_val_FRAMESIZE
                DO      _enum_typedef_val_STKGUARD
                BCC     _enum_typedef_val_stkovf
                CMP     _fcc_stkfloor
                BCS     _enum_typedef_val_stkok
_enum_typedef_val_stkovf       JMP     _fcc_stkoflow
                FIN
_enum_typedef_val_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_enum_typedef_val_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_enum_typedef_val_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_enum_typedef_val_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_enum_typedef_val_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_enum_typedef_val_FRAMESIZE   EQU     0
_enum_typedef_val_STKGUARD    EQU     0
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
                LDA     #3
                STA     gcmd
                LDA     #39
                PHA
                LDA     gcmd
                PHA
                FGX2_FARCALL _enum_typedef_val
                TAY
                PLA
                TYA
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
