                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bsd_struct_test.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT set_point
set_point            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #set_point_FRAMESIZE
                DO      set_point_STKGUARD
                BCC     set_point_stkovf
                CMP     _fcc_stkfloor
                BCS     set_point_stkok
set_point_stkovf       JMP     _fcc_stkoflow
                FIN
set_point_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+set_point_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+set_point_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+set_point_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+set_point_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+set_point_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+set_point_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                LDA     _fcc_img0
                DO      10+set_point_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+set_point_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+set_point_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     [_fcc_img0]
                LDA     _fcc_img0
                DO      12+set_point_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+set_point_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+set_point_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                LDY     #2
                STA     [_fcc_img0],Y
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                DO      14+set_point_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+set_point_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+set_point_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                AND     #$00FF
                SEP     #$20
                MX      %10
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #set_point_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
set_point_FRAMESIZE   EQU     0
set_point_STKGUARD    EQU     0
                FGX2_EXPORT sum_xys
sum_xys            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum_xys_FRAMESIZE
                DO      sum_xys_STKGUARD
                BCC     sum_xys_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_xys_stkok
sum_xys_stkovf       JMP     _fcc_stkoflow
                FIN
sum_xys_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+sum_xys_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_xys_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_xys_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      6+sum_xys_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_xys_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_xys_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img3
                DO      8+sum_xys_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_xys_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_xys_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_bsd_struct_test_L0
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
                BVC     _bsd_struct_test_L2
                EOR     #$8000
_bsd_struct_test_L2
                BPL     _bsd_struct_test_L1
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _bsd_struct_test_L0
_bsd_struct_test_L1
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #sum_xys_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_xys_FRAMESIZE   EQU     4
sum_xys_STKGUARD    EQU     0
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
                LDA     #65
                PHA
                LDA     #7
                PHA
                LDA     #5
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
                FGX2_FARCALL set_point
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #66
                PHA
                LDA     #9
                PHA
                LDA     #8
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
                CLC
                ADC     #6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL set_point
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #67
                PHA
                LDA     #7
                PHA
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
                CLC
                ADC     #12
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL set_point
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #3
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
                FGX2_FARCALL sum_xys
                TAY
                TSC
                CLC
                ADC     #6
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
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
