                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bfold_no.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _bfold_no_viacomplex
_bfold_no_viacomplex            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_bfold_no_viacomplex_FRAMESIZE
                DO      _bfold_no_viacomplex_STKGUARD
                BCC     _bfold_no_viacomplex_stkovf
                CMP     _fcc_stkfloor
                BCS     _bfold_no_viacomplex_stkok
_bfold_no_viacomplex_stkovf       JMP     _fcc_stkoflow
                FIN
_bfold_no_viacomplex_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_bfold_no_viacomplex_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_bfold_no_viacomplex_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_bfold_no_viacomplex_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      10+_bfold_no_viacomplex_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_bfold_no_viacomplex_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_bfold_no_viacomplex_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                PHA
                LDA     gi
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_bfold_no_viacomplex_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bfold_no_viacomplex_FRAMESIZE   EQU     0
_bfold_no_viacomplex_STKGUARD    EQU     0
                FGX2_EXPORT _bfold_no_viaparam
_bfold_no_viaparam            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_bfold_no_viaparam_FRAMESIZE
                DO      _bfold_no_viaparam_STKGUARD
                BCC     _bfold_no_viaparam_stkovf
                CMP     _fcc_stkfloor
                BCS     _bfold_no_viaparam_stkok
_bfold_no_viaparam_stkovf       JMP     _fcc_stkoflow
                FIN
_bfold_no_viaparam_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #5
                STA     1,S   ; fccstk d=0 b=1
                TAX
                DO      6+_bfold_no_viaparam_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_bfold_no_viaparam_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_bfold_no_viaparam_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_bfold_no_viaparam_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bfold_no_viaparam_FRAMESIZE   EQU     2
_bfold_no_viaparam_STKGUARD    EQU     0
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
                LDA     #30
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     cv
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     #1
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL _bfold_no_viacomplex
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL _bfold_no_viaparam
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
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
                FGX2_RELOC_COUNT 6
