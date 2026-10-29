                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from inline_spec.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _inline_spec_twice
_inline_spec_twice            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_inline_spec_twice_FRAMESIZE
                DO      _inline_spec_twice_STKGUARD
                BCC     _inline_spec_twice_stkovf
                CMP     _fcc_stkfloor
                BCS     _inline_spec_twice_stkok
_inline_spec_twice_stkovf       JMP     _fcc_stkoflow
                FIN
_inline_spec_twice_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_inline_spec_twice_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_inline_spec_twice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_inline_spec_twice_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                TAY
                TSC
                CLC
                ADC     #_inline_spec_twice_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_inline_spec_twice_FRAMESIZE   EQU     0
_inline_spec_twice_STKGUARD    EQU     0
                FGX2_EXPORT thrice
thrice            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #thrice_FRAMESIZE
                DO      thrice_STKGUARD
                BCC     thrice_stkovf
                CMP     _fcc_stkfloor
                BCS     thrice_stkok
thrice_stkovf       JMP     _fcc_stkoflow
                FIN
thrice_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+thrice_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+thrice_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+thrice_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #thrice_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
thrice_FRAMESIZE   EQU     0
thrice_STKGUARD    EQU     0
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
                LDA     #9
                PHA
                FGX2_FARCALL _inline_spec_twice
                PLY
                PHA
                LDA     #8
                PHA
                FGX2_FARCALL thrice
                PLY
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
                FGX2_RELOC_COUNT 6
