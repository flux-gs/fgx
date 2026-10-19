                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from renameover.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _renameover_put
_renameover_put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_renameover_put_FRAMESIZE
                DO      _renameover_put_STKGUARD
                BCC     _renameover_put_stkovf
                CMP     _fcc_stkfloor
                BCS     _renameover_put_stkok
_renameover_put_stkovf       JMP     _fcc_stkoflow
                FIN
_renameover_put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #420
                PHA
                DO      10+_renameover_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_renameover_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_renameover_put_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+_renameover_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_renameover_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_renameover_put_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL creat
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _renameover_L1
                EOR     #$8000
_renameover_L1
                BMI     *+5
                BRL     _renameover_L0
                LDA     #1
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #_renameover_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_renameover_L0
                DO      14+_renameover_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_renameover_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_renameover_put_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                PHA
                DO      14+_renameover_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_renameover_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_renameover_put_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+_renameover_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_renameover_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_renameover_put_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL write
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                PHA
                DO      16+_renameover_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_renameover_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_renameover_put_FRAMESIZE,S   ; fccstk d=2 b=14 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _renameover_L2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     #1
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #_renameover_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_renameover_L2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_renameover_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_renameover_put_FRAMESIZE   EQU     2
_renameover_put_STKGUARD    EQU     0
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
                STA     13,S   ; fccstk d=0 b=13
                LDA     #3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _renameover_put
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _renameover_L4
                EOR     #$8000
_renameover_L4
                BMI     *+5
                BRL     _renameover_L3
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
_renameover_L3
                LDA     #6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _renameover_put
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _renameover_L6
                EOR     #$8000
_renameover_L6
                BMI     *+5
                BRL     _renameover_L5
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
_renameover_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL rename
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _renameover_L7
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
_renameover_L7
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _renameover_L9
                EOR     #$8000
_renameover_L9
                BPL     *+5
                BRL     _renameover_L8
                LDA     #6
                PHA
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
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S   ; fccstk d=6 b=9
                PHA
                FGX2_FARCALL read
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     11,S   ; fccstk d=0 b=11
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     11,S   ; fccstk d=0 b=11
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _renameover_L15
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
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #78
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _renameover_L15
                LDA     #1
                BRL     _renameover_L16
_renameover_L15
                LDA     #0
_renameover_L16
                CMP     #0
                BNE     *+5
                BRL     _renameover_L13
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
                LDA     #69
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _renameover_L13
                LDA     #1
                BRL     _renameover_L14
_renameover_L13
                LDA     #0
_renameover_L14
                CMP     #0
                BNE     *+5
                BRL     _renameover_L11
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
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #87
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _renameover_L11
                LDA     #1
                BRL     _renameover_L12
_renameover_L11
                LDA     #0
_renameover_L12
                CMP     #0
                BNE     *+5
                BRL     _renameover_L10
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
_renameover_L10
_renameover_L8
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _renameover_L18
                EOR     #$8000
_renameover_L18
                BMI     *+5
                BRL     _renameover_L17
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
                BRL     _renameover_L19
_renameover_L17
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
_renameover_L19
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _renameover_put
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _renameover_L20
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL rename
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _renameover_L21
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
_renameover_L21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
_renameover_L20
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_renameover_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 20
