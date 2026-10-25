                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m10_flags_test.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT score
score            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #score_FRAMESIZE
                DO      score_STKGUARD
                BCC     score_stkovf
                CMP     _fcc_stkfloor
                BCS     score_stkok
score_stkovf       JMP     _fcc_stkoflow
                FIN
score_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                DO      6+score_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+score_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+score_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                AND     #1
                BEQ     _m10_flags_test_L0
                LDA     _fcc_img0
                CLC
                ADC     #7
                STA     _fcc_img0
_m10_flags_test_L0
                DO      6+score_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+score_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+score_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                AND     #2
                BEQ     _m10_flags_test_L1
                LDA     _fcc_img0
                ORA     #14
                STA     _fcc_img0
_m10_flags_test_L1
                DO      6+score_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+score_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+score_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                AND     #4
                BEQ     _m10_flags_test_L2
                DO      6+score_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+score_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+score_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                AND     #8
                CMP     #0
                BNE     _m10_flags_test_L2
                LDA     _fcc_img0
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shl16
                STA     _fcc_img0
_m10_flags_test_L2
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #score_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
score_FRAMESIZE   EQU     2
score_STKGUARD    EQU     0
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
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                EOR     #$FFFF
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
_m10_flags_test_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                SEC
                SBC     #4
                BVC     _m10_flags_test_L6
                EOR     #$8000
_m10_flags_test_L6
                BPL     _m10_flags_test_L5
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_shl16
                AND     7,S   ; fccstk d=2 b=5
                PHA
                FGX2_FARCALL score
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
_m10_flags_test_L4
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #1
                STA     3,S   ; fccstk d=0 b=3
                BRA     _m10_flags_test_L3
_m10_flags_test_L5
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
