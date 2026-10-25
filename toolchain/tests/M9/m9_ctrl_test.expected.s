                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m9_ctrl_test.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT classify
classify            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #classify_FRAMESIZE
                DO      classify_STKGUARD
                BCC     classify_stkovf
                CMP     _fcc_stkfloor
                BCS     classify_stkok
classify_stkovf       JMP     _fcc_stkoflow
                FIN
classify_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+classify_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+classify_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+classify_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #97
                BEQ     _m9_ctrl_test_L1
                CMP     #65
                BEQ     _m9_ctrl_test_L2
                CMP     #98
                BEQ     _m9_ctrl_test_L3
                CMP     #66
                BEQ     _m9_ctrl_test_L4
                CMP     #99
                BEQ     _m9_ctrl_test_L5
                CMP     #67
                BEQ     _m9_ctrl_test_L6
                BRA     _m9_ctrl_test_L7
_m9_ctrl_test_L1
_m9_ctrl_test_L2
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_m9_ctrl_test_L3
_m9_ctrl_test_L4
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_m9_ctrl_test_L5
_m9_ctrl_test_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_m9_ctrl_test_L7
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_m9_ctrl_test_L0
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
classify_FRAMESIZE   EQU     0
classify_STKGUARD    EQU     0
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
                STA     _fcc_img16
_m9_ctrl_test_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #10
                BVC     _m9_ctrl_test_L11
                EOR     #$8000
_m9_ctrl_test_L11
                BPL     _m9_ctrl_test_L10
                LDA     _fcc_img16
                CMP     #1
                BNE     _m9_ctrl_test_L12
                BRA     _m9_ctrl_test_L9
_m9_ctrl_test_L12
                LDA     _fcc_img16
                TAX
                CMP     #5
                BNE     _m9_ctrl_test_L13
                BRA     _m9_ctrl_test_L10
_m9_ctrl_test_L13
                LDA     _fcc_img17
                PHA
                LDA     #97
                PHA
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #3
                BVC     _m9_ctrl_test_L16
                EOR     #$8000
_m9_ctrl_test_L16
                BPL     _m9_ctrl_test_L14
                LDA     _fcc_img16
                BRA     _m9_ctrl_test_L15
_m9_ctrl_test_L14
                LDA     #0
_m9_ctrl_test_L15
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                FGX2_FARCALL classify
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img17
_m9_ctrl_test_L9
                LDA     _fcc_img16
                TAX
                CLC
                ADC     #1
                STA     _fcc_img16
                BRA     _m9_ctrl_test_L8
_m9_ctrl_test_L10
                LDA     _fcc_img17
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
