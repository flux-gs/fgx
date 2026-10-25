                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bracescalar.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f
f            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f_FRAMESIZE
                DO      f_STKGUARD
                BCC     f_stkovf
                CMP     _fcc_stkfloor
                BCS     f_stkok
f_stkovf       JMP     _fcc_stkoflow
                FIN
f_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                INC
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_bracescalar_S1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     f_sl_k
                PHA
                LDA     [_fcc_img0]
                AND     #$00FF
                TAX
                LDA     #122
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE   EQU     6
f_STKGUARD    EQU     0
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
                LDA     #0
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #101
                BNE     _bracescalar_L0
                LDA     #4
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #116
                BNE     _bracescalar_L0
                LDA     #5
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #0
                BNE     _bracescalar_L0
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #7
                STA     1,S   ; fccstk d=0 b=1
_bracescalar_L0
                LDA     gl+2
                STA     _fcc_long_hi
                LDA     gl
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _bracescalar_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #7
                STA     1,S   ; fccstk d=0 b=1
_bracescalar_L1
                LDA     gi
                CMP     #$FFFD
                BNE     _bracescalar_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #7
                STA     1,S   ; fccstk d=0 b=1
_bracescalar_L2
                LDA     #1
                PHA
                FGX2_FARCALL f
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                CLC
                ADC     #5
                TAX
                INC
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _bracescalar_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #21
                STA     1,S   ; fccstk d=0 b=1
_bracescalar_L3
                LDA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 4
