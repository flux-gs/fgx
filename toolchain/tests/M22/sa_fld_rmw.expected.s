                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sa_fld_rmw.c
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
                STA     _fcc_img0
_sa_fld_rmw_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #4
                BVC     _sa_fld_rmw_L3
                EOR     #$8000
_sa_fld_rmw_L3
                BMI     *+5
                BRL     _sa_fld_rmw_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #10
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                LDY     #10
                STA     [_fcc_fpr0],Y
_sa_fld_rmw_L1
                INC     _fcc_img0
                BRL     _sa_fld_rmw_L0
_sa_fld_rmw_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                DEC
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                INC
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                CLC
                ADC     #5
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #3
                ASL
                CLC
                ADC     #3
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                TAX
                TXA
                SEC
                SBC     #3
                LDY     #8
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #1
                ASL
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #2
                ASL
                INC
                INC
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #blk
                STA     _fcc_fpr0
                LDA     #3
                ASL
                CLC
                ADC     #3
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #8
                LDA     [_fcc_fpr0],Y
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
                FGX2_RELOC_COUNT 2
