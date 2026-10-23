                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bfold_gi.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _bfold_gi_imgfold
_bfold_gi_imgfold            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_bfold_gi_imgfold_FRAMESIZE
                DO      _bfold_gi_imgfold_STKGUARD
                BCC     _bfold_gi_imgfold_stkovf
                CMP     _fcc_stkfloor
                BCS     _bfold_gi_imgfold_stkok
_bfold_gi_imgfold_stkovf       JMP     _fcc_stkoflow
                FIN
_bfold_gi_imgfold_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img1
                LDA     #7
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
_bfold_gi_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _bfold_gi_L3
                EOR     #$8000
_bfold_gi_L3
                BMI     *+5
                BRL     _bfold_gi_L2
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img2
                STA     _fcc_img1
_bfold_gi_L1
                INC     _fcc_img0
                BRL     _bfold_gi_L0
_bfold_gi_L2
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_bfold_gi_imgfold_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_bfold_gi_imgfold_FRAMESIZE   EQU     6
_bfold_gi_imgfold_STKGUARD    EQU     0
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
                LDA     #8
                STA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     ga
                STA     1,S   ; fccstk d=0 b=1
                SEC
                SBC     gb
                STA     1,S   ; fccstk d=0 b=1
                AND     gc
                STA     1,S   ; fccstk d=0 b=1
                ORA     gd
                STA     1,S   ; fccstk d=0 b=1
                EOR     ge
                STA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL _bfold_gi_imgfold
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
