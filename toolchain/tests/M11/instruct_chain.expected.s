                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from instruct_chain.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #a
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #b
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img2
                STA     [_fcc_img0]
                SEP     #$20
                MX      %10
                LDA     _fcc_img3
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
                LDA     #42
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #42
                BEQ     _instruct_chain_L0
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_instruct_chain_L0
                LDA     [_fcc_img0]
                PHA
                LDY     #2
                LDA     [_fcc_img0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #4
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
