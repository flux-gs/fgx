                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from charptr_arr_global.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT scount
scount            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #scount_FRAMESIZE
                DO      scount_STKGUARD
                BCC     scount_stkovf
                CMP     _fcc_stkfloor
                BCS     scount_stkok
scount_stkovf       JMP     _fcc_stkoflow
                FIN
scount_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
_charptr_arr_global_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    scount_sl_pv+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    scount_sl_pv,X
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _charptr_arr_global_L2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _charptr_arr_global_L2
                LDA     #0
                BRA     _charptr_arr_global_L3
_charptr_arr_global_L2
                LDA     #1
_charptr_arr_global_L3
                CMP     #0
                BEQ     _charptr_arr_global_L1
                INC     _fcc_img0
                BRA     _charptr_arr_global_L0
_charptr_arr_global_L1
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #scount_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
scount_FRAMESIZE   EQU     2
scount_STKGUARD    EQU     0
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
                PHA
                LDA     #0
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tbl+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tbl,X
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #3
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    tbl+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    tbl,X
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _charptr_arr_global_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _charptr_arr_global_L6
                LDA     #1
                BRA     _charptr_arr_global_L7
_charptr_arr_global_L6
                LDA     #0
_charptr_arr_global_L7
                CMP     #0
                BEQ     _charptr_arr_global_L4
                LDA     #1
                BRA     _charptr_arr_global_L5
_charptr_arr_global_L4
                LDA     #0
_charptr_arr_global_L5
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL scount
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAX
                SEC
                SBC     #26
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
