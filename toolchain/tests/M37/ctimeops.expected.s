                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ctimeops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT streq
streq            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #streq_FRAMESIZE
                DO      streq_STKGUARD
                BCC     streq_stkovf
                CMP     _fcc_stkfloor
                BCS     streq_stkok
streq_stkovf       JMP     _fcc_stkoflow
                FIN
streq_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+streq_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+streq_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+streq_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+streq_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+streq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+streq_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img0
_ctimeops_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                CMP     #0
                BNE     *+5
                BRL     _ctimeops_L2
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _ctimeops_L2
                LDA     #1
                BRL     _ctimeops_L3
_ctimeops_L2
                LDA     #0
_ctimeops_L3
                CMP     #0
                BNE     *+5
                BRL     _ctimeops_L1
                INC     _fcc_img0
                BRL     _ctimeops_L0
_ctimeops_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_eq16
                TAY
                TSC
                CLC
                ADC     #streq_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
streq_FRAMESIZE   EQU     2
streq_STKGUARD    EQU     0
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
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ctimeops_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ctimeops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL setenv
                TSC
                CLC
                ADC     #10
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ctimeops_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ctime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _ctimeops_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
_ctimeops_L4
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ctimeops_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ctime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _ctimeops_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
_ctimeops_L5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ctimeops_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ctime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _ctimeops_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
_ctimeops_L6
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ctimeops_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #e3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ctime
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL streq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _ctimeops_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
_ctimeops_L7
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
                FGX2_RELOC_COUNT 12
