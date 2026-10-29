                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m19_2d.c
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
_m19_2d_L0
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
                BVC     _m19_2d_L3
                EOR     #$8000
_m19_2d_L3
                BPL     _m19_2d_L2
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
_m19_2d_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _m19_2d_L0
_m19_2d_L2
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
                FGX2_EXPORT sum_grid
sum_grid            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #sum_grid_FRAMESIZE-4
                DO      sum_grid_STKGUARD
                BCC     sum_grid_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_grid_stkok
sum_grid_stkovf       JMP     _fcc_stkoflow
                FIN
sum_grid_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
_m19_2d_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                DO      10+sum_grid_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_grid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_grid_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _m19_2d_L7
                EOR     #$8000
_m19_2d_L7
                BPL     _m19_2d_L6
                LDA     _fcc_img17
                PHA
                LDA     #3
                PHA
                DO      12+sum_grid_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sum_grid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sum_grid_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+sum_grid_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_grid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_grid_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                PHA
                LDA     _fcc_img16
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     12+sum_grid_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum_row
                PLY
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img17
_m19_2d_L5
                LDA     _fcc_img16
                TAX
                CLC
                ADC     #1
                STA     _fcc_img16
                BRL     _m19_2d_L4
_m19_2d_L6
                LDA     _fcc_img17
                TAY
                TSC
                CLC
                ADC     #sum_grid_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_grid_FRAMESIZE   EQU     8
sum_grid_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #matrix
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum_grid
                PLY
                PLY
                PLY
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                TAX
                LDA:    matrix,X
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 6
