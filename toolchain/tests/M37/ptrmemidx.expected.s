                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptrmemidx.c
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img1
                LDA     _fcc_img2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #pool
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_img2]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_img2],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                LDA     #0
                STA     _fcc_img0
_ptrmemidx_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                SEC
                SBC     #4
                BVC     _ptrmemidx_L3
                EOR     #$8000
_ptrmemidx_L3
                BPL     _ptrmemidx_L2
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #10
                STA     [_fcc_fpr0]
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     [_fcc_fpr0]
_ptrmemidx_L1
                INC     _fcc_img0
                BRA     _ptrmemidx_L0
_ptrmemidx_L2
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #4
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                STA     [_fcc_fpr0]
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #10
                BNE     _ptrmemidx_L4
                LDA     _fcc_img1
                CLC
                ADC     #10
                STA     _fcc_img1
_ptrmemidx_L4
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #13
                BNE     _ptrmemidx_L5
                LDA     _fcc_img1
                CLC
                ADC     #10
                STA     _fcc_img1
_ptrmemidx_L5
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #11
                BNE     _ptrmemidx_L6
                LDA     _fcc_img1
                CLC
                ADC     #10
                STA     _fcc_img1
_ptrmemidx_L6
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #8
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     [_fcc_img2]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #12
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                CMP     #5
                BNE     _ptrmemidx_L7
                LDA     _fcc_img1
                TAX
                CLC
                ADC     #12
                STA     _fcc_img1
_ptrmemidx_L7
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
