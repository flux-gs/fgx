                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from strinit.c
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
                LDA     #119
                SEP     #$20
                MX      %10
                STA     1,S   ; fccstk d=0 b=1
                REP     #$20
                MX      %00
                LDA     #111
                SEP     #$20
                MX      %10
                STA     2,S   ; fccstk d=0 b=2
                REP     #$20
                MX      %00
                LDA     #114
                SEP     #$20
                MX      %10
                STA     3,S   ; fccstk d=0 b=3
                REP     #$20
                MX      %00
                LDA     #108
                SEP     #$20
                MX      %10
                STA     4,S   ; fccstk d=0 b=4
                REP     #$20
                MX      %00
                LDA     #100
                SEP     #$20
                MX      %10
                STA     5,S   ; fccstk d=0 b=5
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     6,S   ; fccstk d=0 b=6
                REP     #$20
                MX      %00
                LDA     #104
                SEP     #$20
                MX      %10
                STA     7,S   ; fccstk d=0 b=7
                REP     #$20
                MX      %00
                LDA     #105
                SEP     #$20
                MX      %10
                STA     8,S   ; fccstk d=0 b=8
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     9,S   ; fccstk d=0 b=9
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     10,S   ; fccstk d=0 b=10
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     11,S   ; fccstk d=0 b=11
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     12,S   ; fccstk d=0 b=12
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     13,S   ; fccstk d=0 b=13
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     14,S   ; fccstk d=0 b=14
                REP     #$20
                MX      %00
                LDA     #30
                STA     15,S   ; fccstk d=0 b=15
                LDA     #2
                STA     17,S   ; fccstk d=0 b=17
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bx
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0+2
                STA     21,S   ; fccstk d=0 b=21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #bx
                STA     _fcc_fpr0
                STA     23,S   ; fccstk d=0 b=23
                LDA     _fcc_fpr0+2
                STA     25,S   ; fccstk d=0 b=25
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #111
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #5
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #4
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #100
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _strinit_L0
                LDA     #5
                BRL     _strinit_L1
_strinit_L0
                LDA     #0
_strinit_L1
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #104
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                PHA
                LDA     #7
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #105
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _strinit_L2
                LDA     #3
                BRL     _strinit_L3
_strinit_L2
                LDA     #0
_strinit_L3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                LDA     #bx
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #2
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
                LDA     _fcc_img0
                PHA
                LDA     _fcc_fb
                CLC
                ADC     #18
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
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
                STA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
