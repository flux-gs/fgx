                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from typespecorder.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pick
pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pick_FRAMESIZE
                DO      pick_STKGUARD
                BCC     pick_stkovf
                CMP     _fcc_stkfloor
                BCS     pick_stkok
pick_stkovf       JMP     _fcc_stkoflow
                FIN
pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _typespecorder_L2
                EOR     #$8000
_typespecorder_L2
                BMI     *+5
                BRL     _typespecorder_L0
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                BRL     _typespecorder_L1
_typespecorder_L0
                DO      8+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
_typespecorder_L1
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pick_FRAMESIZE   EQU     0
pick_STKGUARD    EQU     0
                FGX2_EXPORT mask
mask            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mask_FRAMESIZE
                DO      mask_STKGUARD
                BCC     mask_stkovf
                CMP     _fcc_stkfloor
                BCS     mask_stkok
mask_stkovf       JMP     _fcc_stkoflow
                FIN
mask_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+mask_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+mask_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+mask_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                AND     #255
                TAY
                TSC
                CLC
                ADC     #mask_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mask_FRAMESIZE   EQU     0
mask_STKGUARD    EQU     0
                FGX2_EXPORT big
big            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #big_FRAMESIZE
                DO      big_STKGUARD
                BCC     big_stkovf
                CMP     _fcc_stkfloor
                BCS     big_stkok
big_stkovf       JMP     _fcc_stkoflow
                FIN
big_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+big_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+big_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+big_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+big_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+big_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+big_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #15
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                TAY
                TSC
                CLC
                ADC     #big_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
big_FRAMESIZE   EQU     0
big_STKGUARD    EQU     0
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
                LDA     #40
                PHA
                LDA     #20
                PHA
                FGX2_FARCALL pick
                TAY
                PLA
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #274
                PHA
                FGX2_FARCALL mask
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0024
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL big
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 8
