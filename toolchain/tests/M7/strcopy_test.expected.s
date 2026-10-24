                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from strcopy_test.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT copy
copy            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #copy_FRAMESIZE
                DO      copy_STKGUARD
                BCC     copy_stkovf
                CMP     _fcc_stkfloor
                BCS     copy_stkok
copy_stkovf       JMP     _fcc_stkoflow
                FIN
copy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+copy_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+copy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+copy_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      12+copy_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+copy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+copy_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img1
                DO      6+copy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+copy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+copy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+copy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+copy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+copy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
_strcopy_test_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img0]
                AND     #$00FF
                CMP     #0
                BNE     *+5
                BRL     _strcopy_test_L1
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     [_fcc_img0]
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     _fcc_img2
                INC
                STA     _fcc_img2
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
                BRL     _strcopy_test_L0
_strcopy_test_L1
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #copy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
copy_FRAMESIZE   EQU     0
copy_STKGUARD    EQU     0
                FGX2_EXPORT strlen_
strlen_            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #strlen__FRAMESIZE
                DO      strlen__STKGUARD
                BCC     strlen__stkovf
                CMP     _fcc_stkfloor
                BCS     strlen__stkok
strlen__stkovf       JMP     _fcc_stkoflow
                FIN
strlen__stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+strlen__FRAMESIZE/256
                TSC
                CLC
                ADC     #8+strlen__FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+strlen__FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+strlen__FRAMESIZE/256
                TSC
                CLC
                ADC     #6+strlen__FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+strlen__FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
_strcopy_test_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img0]
                AND     #$00FF
                CMP     #0
                BNE     *+5
                BRL     _strcopy_test_L3
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
                BRL     _strcopy_test_L2
_strcopy_test_L3
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                DO      8+strlen__FRAMESIZE/256
                TSC
                CLC
                ADC     #8+strlen__FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+strlen__FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+strlen__FRAMESIZE/256
                TSC
                CLC
                ADC     #6+strlen__FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+strlen__FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAY
                TSC
                CLC
                ADC     #strlen__FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
strlen__FRAMESIZE   EQU     4
strlen__STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     g_greet+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     g_greet
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL copy
                TSC
                CLC
                ADC     #8
                TCS
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strlen_
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 6
