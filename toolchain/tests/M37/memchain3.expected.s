                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from memchain3.c
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
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     _fcc_img0
                LDA     #4
                STA     pa+0
                LDA     #6
                STA     pb+0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #pa
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #12
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #pb
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_ptr+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     #msg
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #90
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
                LDA     #msg
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #msg
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_ptr+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                CLC
                ADC     #4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
_memchain3_L0
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _memchain3_L0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
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
                CLC
                ADC     #8
                STA     _fcc_fpr0
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
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #4
                BEQ     *+5
                BRL     _memchain3_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_memchain3_L1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
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
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _memchain3_L2
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_memchain3_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
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
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     19,S   ; fccstk d=0 b=19
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _memchain3_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #10
                STA     _fcc_img0
_memchain3_L3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
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
                CLC
                ADC     #12
                STA     _fcc_fpr0
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
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BNE     *+5
                BRL     _memchain3_L4
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
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
                CLC
                ADC     #12
                STA     _fcc_fpr0
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
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     27,S   ; fccstk d=0 b=27
                LDA     _fcc_fpr0
                STA     25,S   ; fccstk d=0 b=25
                LDA     27,S   ; fccstk d=0 b=27
                STA     _fcc_fpr0+2
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #6
                BEQ     *+5
                BRL     _memchain3_L5
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #12
                STA     _fcc_img0
_memchain3_L5
_memchain3_L4
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
main_FRAMESIZE   EQU     68
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
