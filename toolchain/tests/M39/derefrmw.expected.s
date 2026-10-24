                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from derefrmw.c
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
                LDA     #2
                STA     _fcc_img1
                LDA     #85
                STA     5,S   ; fccstk d=0 b=5
                LDA     #3
                CLC
                ADC     #_derefrmw_buf
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     #4
                ASL
                CLC
                ADC     #_derefrmw_s
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _derefrmw_fp
                LDA     _fcc_fpr0+2
                STA     _derefrmw_fp+2
                LDA     #_derefrmw_s
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #7
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                LDA     _derefrmw_fp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _derefrmw_fp
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                DEC
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _derefrmw_fp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _derefrmw_fp
                STA     _fcc_fpr0
                LDA     _fcc_img1
                ASL
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                DEC
                STA     [_fcc_fpr0]
                STA     _fcc_img0
                TAX
                TXA
                CMP     #5
                BNE     _derefrmw_L1
                LDA     #2
                ASL
                TAX
                LDA:    _derefrmw_s,X
                TAX
                TXA
                CMP     #5
                BNE     _derefrmw_L1
                LDA     #0
                BRA     _derefrmw_L2
_derefrmw_L1
                LDA     #1
_derefrmw_L2
                CMP     #0
                BEQ     _derefrmw_L0
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
_derefrmw_L0
                LDA     #_derefrmw_buf
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #240
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                DEC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                EOR     _fcc_tmp_b
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #2
                TAX
                LDA:    _derefrmw_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #165
                BEQ     _derefrmw_L3
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
_derefrmw_L3
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                DEC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CLC
                ADC     #3
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #2
                TAX
                LDA:    _derefrmw_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #168
                BEQ     _derefrmw_L4
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
_derefrmw_L4
                LDA     #_derefrmw_s
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #9
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                SEP     #$20
                MX      %10
                LDA     _derefrmw_sp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _derefrmw_sp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                DEC
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _derefrmw_sp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _derefrmw_sp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _derefrmw_sp+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _derefrmw_sp
                STA     _fcc_fpr1
                LDA     [_fcc_fpr1]
                TAX
                TXA
                DEC
                STA     [_fcc_fpr0]
                STA     _fcc_img0
                TAX
                TXA
                CMP     #7
                BNE     _derefrmw_L6
                LDA     #0
                ASL
                TAX
                LDA:    _derefrmw_s,X
                TAX
                TXA
                CMP     #7
                BNE     _derefrmw_L6
                LDA     #0
                BRA     _derefrmw_L7
_derefrmw_L6
                LDA     #1
_derefrmw_L7
                CMP     #0
                BEQ     _derefrmw_L5
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_derefrmw_L5
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
