                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from va_args.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sum3
sum3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum3_FRAMESIZE
                DO      sum3_STKGUARD
                BCC     sum3_stkovf
                CMP     _fcc_stkfloor
                BCS     sum3_stkok
sum3_stkovf       JMP     _fcc_stkoflow
                FIN
sum3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sum3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      8+sum3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum3_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                DO      10+sum3_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum3_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sum3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum3_FRAMESIZE   EQU     0
sum3_STKGUARD    EQU     0
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
                LDA     #21
                PHA
                LDA     #20
                PHA
                FGX2_FARCALL sum3
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
