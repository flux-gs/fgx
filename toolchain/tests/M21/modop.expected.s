                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from modop.c
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
                LDA     #100
                LDX     #7
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                LDA     #7
                LDX     #5
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                LDA     #40
                STA     _fcc_img1
                TAX
                LDA     #12
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mods16
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                LDA     #38
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
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
                FGX2_RELOC_COUNT 2
