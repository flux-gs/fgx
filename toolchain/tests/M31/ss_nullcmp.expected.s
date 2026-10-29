                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ss_nullcmp.c
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
                LDA     #0
                STA     _fcc_img0
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
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                SEP     #$20
                MX      %10
                LDA     gnull+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gnull
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ss_nullcmp_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ss_nullcmp_L1
                LDA     #1
                BRA     _ss_nullcmp_L2
_ss_nullcmp_L1
                LDA     #0
_ss_nullcmp_L2
                CMP     #0
                BEQ     _ss_nullcmp_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
_ss_nullcmp_L0
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ss_nullcmp_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ss_nullcmp_L4
                LDA     #1
                BRA     _ss_nullcmp_L5
_ss_nullcmp_L4
                LDA     #0
_ss_nullcmp_L5
                CMP     #0
                BEQ     _ss_nullcmp_L3
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #100
                STA     _fcc_img0
_ss_nullcmp_L3
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _ss_nullcmp_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _ss_nullcmp_L7
                LDA     #0
                BRA     _ss_nullcmp_L8
_ss_nullcmp_L7
                LDA     #1
_ss_nullcmp_L8
                CMP     #0
                BEQ     _ss_nullcmp_L6
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #41
                STA     _fcc_img0
_ss_nullcmp_L6
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
