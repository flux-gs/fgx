                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from retlongneg.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT retneg
retneg            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #retneg_FRAMESIZE
                DO      retneg_STKGUARD
                BCC     retneg_stkovf
                CMP     _fcc_stkfloor
                BCS     retneg_stkok
retneg_stkovf       JMP     _fcc_stkoflow
                FIN
retneg_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+retneg_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+retneg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+retneg_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #0
                BNE     *+5
                BRL     _retlongneg_L0
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #retneg_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_retlongneg_L0
                LDA     #65
                JSR     _fcc_long_from_int
                TAY
                TSC
                CLC
                ADC     #retneg_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
retneg_FRAMESIZE   EQU     0
retneg_STKGUARD    EQU     0
                FGX2_EXPORT retbig
retbig            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #retbig_FRAMESIZE
                DO      retbig_STKGUARD
                BCC     retbig_stkovf
                CMP     _fcc_stkfloor
                BCS     retbig_stkok
retbig_stkovf       JMP     _fcc_stkoflow
                FIN
retbig_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                TSC
                CLC
                ADC     #retbig_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
retbig_FRAMESIZE   EQU     0
retbig_STKGUARD    EQU     0
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
                LDA     #1
                PHA
                FGX2_FARCALL retneg
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _retlongneg_L1
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
_retlongneg_L1
                LDA     #1
                PHA
                FGX2_FARCALL retneg
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ges
                CMP     #0
                BNE     *+5
                BRL     _retlongneg_L2
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
_retlongneg_L2
                LDA     #0
                PHA
                FGX2_FARCALL retneg
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0041
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _retlongneg_L3
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
_retlongneg_L3
                FGX2_FARCALL retbig
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _retlongneg_L4
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
_retlongneg_L4
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
