                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from init_list_test.c
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
                LDA     #0
                ASL
                TAX
                LDA:    g_explicit,X
                PHA
                LDA     #1
                ASL
                TAX
                LDA:    g_explicit,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #2
                ASL
                TAX
                LDA:    g_explicit,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #3
                ASL
                TAX
                LDA:    g_explicit,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #4
                ASL
                TAX
                LDA:    g_explicit,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                LDA     #0
                ASL
                TAX
                LDA:    g_inferred,X
                PHA
                LDA     #1
                ASL
                TAX
                LDA:    g_inferred,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #2
                ASL
                TAX
                LDA:    g_inferred,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     #2
                ASL
                TAX
                LDA:    g_negs,X
                PHA
                LDA     #0
                ASL
                TAX
                LDA:    g_negs,X
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                PHA
                LDA     #1
                ASL
                TAX
                LDA:    g_negs,X
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                PHA
                LDA     #2
                ASL
                TAX
                LDA:    g_negs,X
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_img0
                TAX
                CMP     #42
                BEQ     _init_list_test_L0
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
_init_list_test_L0
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #42
                BEQ     _init_list_test_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_list_test_L1
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #3
                BEQ     _init_list_test_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_init_list_test_L2
                LDA     _fcc_img0
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
                FGX2_RELOC_COUNT 2
