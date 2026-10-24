                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from enum_as_type.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _enum_as_type_take_enum
_enum_as_type_take_enum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_enum_as_type_take_enum_FRAMESIZE
                DO      _enum_as_type_take_enum_STKGUARD
                BCC     _enum_as_type_take_enum_stkovf
                CMP     _fcc_stkfloor
                BCS     _enum_as_type_take_enum_stkok
_enum_as_type_take_enum_stkovf       JMP     _fcc_stkoflow
                FIN
_enum_as_type_take_enum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_enum_as_type_take_enum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_enum_as_type_take_enum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_enum_as_type_take_enum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_enum_as_type_take_enum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_enum_as_type_take_enum_FRAMESIZE   EQU     0
_enum_as_type_take_enum_STKGUARD    EQU     0
                FGX2_EXPORT _enum_as_type_take_enum_ptr
_enum_as_type_take_enum_ptr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_enum_as_type_take_enum_ptr_FRAMESIZE
                DO      _enum_as_type_take_enum_ptr_STKGUARD
                BCC     _enum_as_type_take_enum_ptr_stkovf
                CMP     _fcc_stkfloor
                BCS     _enum_as_type_take_enum_ptr_stkok
_enum_as_type_take_enum_ptr_stkovf       JMP     _fcc_stkoflow
                FIN
_enum_as_type_take_enum_ptr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_enum_as_type_take_enum_ptr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_enum_as_type_take_enum_ptr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_enum_as_type_take_enum_ptr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+_enum_as_type_take_enum_ptr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_enum_as_type_take_enum_ptr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_enum_as_type_take_enum_ptr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAY
                TSC
                CLC
                ADC     #_enum_as_type_take_enum_ptr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_enum_as_type_take_enum_ptr_FRAMESIZE   EQU     0
_enum_as_type_take_enum_ptr_STKGUARD    EQU     0
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
                LDA     #2
                STA     g_type
                LDA     #4
                STA     g_vnode+2
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                LDA     g_type
                PHA
                FGX2_FARCALL _enum_as_type_take_enum
                TAY
                PLA
                TYA
                STA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     g_vnode+2
                PHA
                FGX2_FARCALL _enum_as_type_take_enum
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _enum_as_type_take_enum_ptr
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
                STA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #3
                STA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     #8
                TAX
                CLC
                ADC     #10
                TAX
                CLC
                ADC     #4
                TAX
                CLC
                ADC     #4
                TAX
                CLC
                ADC     #65533
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #9
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
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
