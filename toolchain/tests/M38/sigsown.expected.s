                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sigsown.c
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
                LDA     #dst
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #120
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
                LDA     #dst
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_sigsown_S1
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
                LDA     #_sigsown_S0
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
                LDA     #dst
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fill
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_EXPORT fill
fill            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fill_FRAMESIZE
                DO      fill_STKGUARD
                BCC     fill_stkovf
                CMP     _fcc_stkfloor
                BCS     fill_stkok
fill_stkovf       JMP     _fcc_stkoflow
                FIN
fill_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #120
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sigsown_L3
                DO      12+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fill_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+fill_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #98
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sigsown_L3
                LDA     #1
                BRL     _sigsown_L4
_sigsown_L3
                LDA     #0
_sigsown_L4
                CMP     #0
                BNE     *+5
                BRL     _sigsown_L1
                DO      16+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+fill_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_ptr+2
                DO      14+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+fill_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #99
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _sigsown_L1
                LDA     #1
                BRL     _sigsown_L2
_sigsown_L1
                LDA     #0
_sigsown_L2
                CMP     #0
                BNE     *+5
                BRL     _sigsown_L0
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_sigsown_L0
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fill_FRAMESIZE   EQU     0
fill_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
