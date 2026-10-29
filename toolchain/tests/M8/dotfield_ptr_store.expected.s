                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dotfield_ptr_store.c
;---------------------------------------

                MX      %00
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
                LDA     #42
                STA     7,S   ; fccstk d=0 b=7
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
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
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
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_ptr+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     [_fcc_img2]
                PHA
                LDY     #2
                LDA     [_fcc_img2],Y
                STA     _fcc_fpr1+2
                PLA
                STA     _fcc_fpr1
                STA     [_fcc_img0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_img0],Y
                REP     #$20
                MX      %00
                LDA     [_fcc_img0]
                PHA
                LDY     #2
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
