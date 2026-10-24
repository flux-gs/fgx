                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_arr_init.c
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img1
_struct_arr_init_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _struct_arr_init_L3
                EOR     #$8000
_struct_arr_init_L3
                BMI     *+5
                BRL     _struct_arr_init_L2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #items
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
_struct_arr_init_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
                BRL     _struct_arr_init_L0
_struct_arr_init_L2
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_img1
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_struct_arr_init_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     #items
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strcmp
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _struct_arr_init_L4
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_struct_arr_init_L4
                LDA     3,S   ; fccstk d=0 b=3
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
                FGX2_RELOC_COUNT 3
