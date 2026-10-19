                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bfold_far.c
;---------------------------------------

                MX      %00
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
                LDA     #5
                STA     1,S   ; fccstk d=0 b=1
                LDA     #7
                STA     3,S   ; fccstk d=0 b=3
                LDA     #9
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     _fcc_img0
_bfold_far_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #126
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _bfold_far_L3
                EOR     #$8000
_bfold_far_L3
                BMI     *+5
                BRL     _bfold_far_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     _fcc_img0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
_bfold_far_L1
                INC     _fcc_img0
                BRL     _bfold_far_L0
_bfold_far_L2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                CLC
                ADC     5,S   ; fccstk d=2 b=3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     gg
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #125
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
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
main_FRAMESIZE   EQU     260
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 2
