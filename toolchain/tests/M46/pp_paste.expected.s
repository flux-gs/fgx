                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pp_paste.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _pp_paste_same
_pp_paste_same            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_pp_paste_same_FRAMESIZE
                DO      _pp_paste_same_STKGUARD
                BCC     _pp_paste_same_stkovf
                CMP     _fcc_stkfloor
                BCS     _pp_paste_same_stkok
_pp_paste_same_stkovf       JMP     _fcc_stkoflow
                FIN
_pp_paste_same_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_pp_paste_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_pp_paste_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_pp_paste_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+_pp_paste_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_pp_paste_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_pp_paste_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
                DO      10+_pp_paste_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_pp_paste_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_pp_paste_same_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      12+_pp_paste_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_pp_paste_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_pp_paste_same_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img3
_pp_paste_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img0]
                AND     #$00FF
                CMP     #0
                BEQ     _pp_paste_L1
                LDA     [_fcc_img0]
                AND     #$00FF
                PHA
                LDA     [_fcc_img2]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _pp_paste_L1
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                STA     _fcc_img0
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #1
                STA     _fcc_img2
                BRA     _pp_paste_L0
_pp_paste_L1
                LDA     [_fcc_img0]
                AND     #$00FF
                PHA
                LDA     [_fcc_img2]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_eq16
                TAY
                TSC
                CLC
                ADC     #_pp_paste_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pp_paste_same_FRAMESIZE   EQU     0
_pp_paste_same_STKGUARD    EQU     0
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
                LDA     var123
                CLC
                ADC     xONE
                CLC
                ADC     x1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #3
                STA     cat3_obj
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pp_paste_S0
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
                LDA     #_pp_paste_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _pp_paste_same
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _pp_paste_L2
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pp_paste_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pp_paste_S1
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
                LDA     #_pp_paste_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _pp_paste_same
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _pp_paste_L3
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pp_paste_L3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_pp_paste_S2
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
                LDA     #_pp_paste_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _pp_paste_same
                PLY
                PLY
                PLY
                PLY
                CMP     #0
                BNE     _pp_paste_L4
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pp_paste_L4
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     cat3_obj
                TAX
                SEC
                SBC     #3
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
