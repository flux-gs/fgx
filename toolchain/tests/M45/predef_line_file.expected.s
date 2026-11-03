                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from predef_line_file.c
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
_predef_line_file_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA:    name,X
                AND     #$00FF
                CMP     #0
                BEQ     _predef_line_file_L2
_predef_line_file_L1
                INC     _fcc_img0
                BRA     _predef_line_file_L0
_predef_line_file_L2
                LDA     #0
                STA     _fcc_img1
                LDA     #17
                CMP     #17
                BNE     _predef_line_file_L3
                LDA     _fcc_img1
                CLC
                ADC     #10
                STA     _fcc_img1
_predef_line_file_L3
                LDA     #18
                CMP     #18
                BNE     _predef_line_file_L4
                LDA     _fcc_img1
                CLC
                ADC     #20
                STA     _fcc_img1
_predef_line_file_L4
                LDA     _fcc_img0
                LDX     #6
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _predef_line_file_L6
                EOR     #$8000
_predef_line_file_L6
                BPL     _predef_line_file_L5
                LDA     _fcc_img0
                SEC
                SBC     #6
                TAX
                LDA:    name,X
                AND     #$00FF
                TAX
                CMP     #102
                BNE     _predef_line_file_L5
                LDA     _fcc_img0
                DEC
                TAX
                LDA:    name,X
                AND     #$00FF
                TAX
                CMP     #99
                BNE     _predef_line_file_L5
                LDA     _fcc_img1
                TAX
                CLC
                ADC     #12
                STA     _fcc_img1
_predef_line_file_L5
                LDA     _fcc_img1
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
