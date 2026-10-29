                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from str_walk.c
;---------------------------------------

                MX      %00
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
_str_walk_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img0]
                AND     #$00FF
                BEQ     _str_walk_L1
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _str_walk_L0
_str_walk_L1
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_str_walk_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strlen_
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
