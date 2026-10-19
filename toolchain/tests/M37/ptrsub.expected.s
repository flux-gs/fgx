                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptrsub.c
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #wtab
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ctab
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                LDA     #10
                STA     _fcc_img0
                LDA     #wtab
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #3
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                LDA     #ctab
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #33
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
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #15
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     #1
                ASL
                TAX
                LDA:    wtab,X
                TAX
                LDA     #19
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _ptrsub_L0
                LDA     _fcc_img0
                TAX
                LDA     #16
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_ptrsub_L0
                LDA     #2
                TAX
                LDA:    ctab,X
                AND     #$00FF
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _ptrsub_L1
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_ptrsub_L1
                LDA     _fcc_img0
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptrsub_L3
                EOR     #$8000
_ptrsub_L3
                BMI     *+5
                BRL     _ptrsub_L2
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
_ptrsub_L2
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
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
