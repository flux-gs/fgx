                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT compute
compute            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #compute_FRAMESIZE
                DO      compute_STKGUARD
                BCC     compute_stkovf
                CMP     _fcc_stkfloor
                BCS     compute_stkok
compute_stkovf       JMP     _fcc_stkoflow
                FIN
compute_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+compute_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+compute_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+compute_FRAMESIZE,S   ; fccstk d=0 b=14 fs
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
_long_param_L0
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
                BVC     _long_param_L3
                EOR     #$8000
_long_param_L3
                BPL     _long_param_L2
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+compute_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+compute_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+compute_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      10+compute_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+compute_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+compute_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+compute_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+compute_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+compute_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+compute_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+compute_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+compute_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
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
_long_param_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
                BRL     _long_param_L0
_long_param_L2
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                TAY
                TSC
                CLC
                ADC     #compute_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
compute_FRAMESIZE   EQU     6
compute_STKGUARD    EQU     0
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
                LDA     #$0003
                STA     _fcc_long_hi
                LDA     #$0D40
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL compute
                TAY
                TSC
                CLC
                ADC     #10
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
                LDX     #37814
                STX     _fcc_long_b_lo
                LDX     #4
                STX     _fcc_long_b_hi
                JSR     _fcc_long_sub
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
