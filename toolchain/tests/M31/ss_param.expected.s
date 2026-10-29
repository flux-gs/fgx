                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ss_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT calc
calc            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #calc_FRAMESIZE
                DO      calc_STKGUARD
                BCC     calc_stkovf
                CMP     _fcc_stkfloor
                BCS     calc_stkok
calc_stkovf       JMP     _fcc_stkoflow
                FIN
calc_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+calc_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+calc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+calc_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+calc_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+calc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+calc_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                DO      10+calc_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+calc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+calc_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img1
                TYA
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     _fcc_img1
                STA     _fcc_long_hi
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #calc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
calc_FRAMESIZE   EQU     6
calc_STKGUARD    EQU     0
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
                LDA     #12
                PHA
                LDA     #20
                PHA
                LDA     #10
                PHA
                FGX2_FARCALL calc
                PLY
                PLY
                PLY
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
                FGX2_RELOC_COUNT 4
