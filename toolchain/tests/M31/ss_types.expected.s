                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ss_types.c
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
                LDA     #100
                STA     _fcc_img2
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                LDA     #5
                STA     5,S   ; fccstk d=0 b=5
                LDA     #30
                STA     7,S   ; fccstk d=0 b=7
                LDA     #gbuf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #7
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbuf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                SEC
                SBC     7,S   ; fccstk d=0 b=7
                PHA
                LDA     [_fcc_img0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                TAX
                SEC
                SBC     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
