                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m20_long.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sum_longs
sum_longs            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum_longs_FRAMESIZE
                DO      sum_longs_STKGUARD
                BCC     sum_longs_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_longs_stkok
sum_longs_stkovf       JMP     _fcc_stkoflow
                FIN
sum_longs_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+sum_longs_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_longs_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_longs_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     #0
                STA     _fcc_img0
_m20_long_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _m20_long_L3
                EOR     #$8000
_m20_long_L3
                BPL     _m20_long_L2
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+sum_longs_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sum_longs_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sum_longs_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+sum_longs_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_longs_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_longs_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                CLC
                ADC     #2
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
_m20_long_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
                BRL     _m20_long_L0
_m20_long_L2
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                TAY
                TSC
                CLC
                ADC     #sum_longs_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_longs_FRAMESIZE   EQU     6
sum_longs_STKGUARD    EQU     0
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
                LDA     #ages
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum_longs
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0004
                STA     _fcc_long_hi
                LDA     #$9444
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
