                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dblparen_lv.c
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
                LDA     #gv
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #40
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #1
                BEQ     _dblparen_lv_L0
                LDA     #gv
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                TAX
                CLC
                ADC     #2
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
_dblparen_lv_L0
                LDA     #15
                TAX
                AND     #6
                STA     _fcc_img0
                LDA     #100
                STA     gsv
                LDA     #7
                STA     gsv
                LDA     _fcc_img0
                TAX
                CMP     #6
                BEQ     _dblparen_lv_L1
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
_dblparen_lv_L1
                LDA     gsv
                TAX
                CMP     #7
                BEQ     _dblparen_lv_L2
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
_dblparen_lv_L2
                LDA     #0
                ASL
                TAX
                LDA:    gv,X
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
                FGX2_RELOC_COUNT 2
