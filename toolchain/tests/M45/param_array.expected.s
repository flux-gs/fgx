                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from param_array.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT lsum
lsum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #lsum_FRAMESIZE
                DO      lsum_STKGUARD
                BCC     lsum_stkovf
                CMP     _fcc_stkfloor
                BCS     lsum_stkok
lsum_stkovf       JMP     _fcc_stkoflow
                FIN
lsum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+lsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+lsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+lsum_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
                DO      6+lsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+lsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+lsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+lsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+lsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+lsum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img4
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img5
                TYA
                LDA     #0
                STA     _fcc_img0
_param_array_L0
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
                BVC     _param_array_L3
                EOR     #$8000
_param_array_L3
                BPL     _param_array_L2
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
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
                STA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img5
                TYA
_param_array_L1
                INC     _fcc_img0
                BRA     _param_array_L0
_param_array_L2
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                TAY
                TSC
                CLC
                ADC     #lsum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
lsum_FRAMESIZE   EQU     6
lsum_STKGUARD    EQU     0
                FGX2_EXPORT ptsum
ptsum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ptsum_FRAMESIZE
                DO      ptsum_STKGUARD
                BCC     ptsum_stkovf
                CMP     _fcc_stkfloor
                BCS     ptsum_stkok
ptsum_stkovf       JMP     _fcc_stkoflow
                FIN
ptsum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+ptsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ptsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ptsum_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      6+ptsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ptsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ptsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img3
                DO      8+ptsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ptsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ptsum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_param_array_L4
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
                BVC     _param_array_L7
                EOR     #$8000
_param_array_L7
                BPL     _param_array_L6
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
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
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
_param_array_L5
                INC     _fcc_img0
                BRA     _param_array_L4
_param_array_L6
                LDA     _fcc_img4
                STA     _fcc_fpr0+2
                LDA     _fcc_img3
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     #7
                STA     [_fcc_fpr0]
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #ptsum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ptsum_FRAMESIZE   EQU     4
ptsum_STKGUARD    EQU     0
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
                LDA     #gl
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL lsum
                PLY
                PLY
                PLY
                LDX     #34476
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _param_array_L8
                LDA     #0
                ASL
                ASL
                TAX
                LDA:    gl+2,X
                STA     _fcc_long_hi
                LDA:    gl,X
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _param_array_L8
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #20
                STA     1,S   ; fccstk d=0 b=1
_param_array_L8
                LDA     #2
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gp
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ptsum
                PLY
                PLY
                PLY
                TAX
                CMP     #10
                BNE     _param_array_L9
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #gp
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #7
                BNE     _param_array_L9
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #22
                STA     1,S   ; fccstk d=0 b=1
_param_array_L9
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
                FGX2_RELOC_COUNT 6
