                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m2d_partial.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sum_row
sum_row            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum_row_FRAMESIZE
                DO      sum_row_STKGUARD
                BCC     sum_row_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_row_stkok
sum_row_stkovf       JMP     _fcc_stkoflow
                FIN
sum_row_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+sum_row_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_row_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_row_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      6+sum_row_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_row_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_row_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img3
                DO      8+sum_row_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_row_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_row_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_m2d_partial_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _m2d_partial_L3
                EOR     #$8000
_m2d_partial_L3
                BMI     *+5
                BRL     _m2d_partial_L2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
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
                STA     _fcc_img1
_m2d_partial_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
                BRL     _m2d_partial_L0
_m2d_partial_L2
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #sum_row_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_row_FRAMESIZE   EQU     4
sum_row_STKGUARD    EQU     0
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
                LDA     #3
                PHA
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA     #g
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum_row
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                PHA
                LDA     #3
                PHA
                LDA     #1
                ASL
                INC
                ASL
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA     #g
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum_row
                TAY
                TSC
                CLC
                ADC     #6
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
                FGX2_RELOC_COUNT 5
