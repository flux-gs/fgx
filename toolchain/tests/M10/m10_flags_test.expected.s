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
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
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
                STA     _fcc_img17
                LDA     #0
                EOR     #$FFFF
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     _fcc_img16
_m10_flags_test_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #4
                BVC     _m10_flags_test_L6
                EOR     #$8000
_m10_flags_test_L6
                BPL     _m10_flags_test_L5
                LDA     _fcc_img17
                PHA
                LDA     #1
                TAX
                LDA     _fcc_img16
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shl16
                AND     7,S   ; fccstk d=2 b=5
                PHA
                FGX2_FARCALL score
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img17
_m10_flags_test_L4
                LDA     _fcc_img16
                TAX
                CLC
                ADC     #1
                STA     _fcc_img16
                BRA     _m10_flags_test_L3
_m10_flags_test_L5
                LDA     _fcc_img17
                ASL
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
