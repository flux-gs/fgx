                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from constexpr_relop.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT classify
classify            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #classify_FRAMESIZE
                DO      classify_STKGUARD
                BCC     classify_stkovf
                CMP     _fcc_stkfloor
                BCS     classify_stkok
classify_stkovf       JMP     _fcc_stkoflow
                FIN
classify_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+classify_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+classify_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+classify_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #10
                BNE     *+5
                BRL     _constexpr_relop_L1
                CMP     #20
                BNE     *+5
                BRL     _constexpr_relop_L2
                BRL     _constexpr_relop_L3
_constexpr_relop_L1
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_constexpr_relop_L2
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_constexpr_relop_L3
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_constexpr_relop_L0
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #classify_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
classify_FRAMESIZE   EQU     0
classify_STKGUARD    EQU     0
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
                TAX
                LDA:    _sa_dinode_is_64,X
                AND     #$00FF
                PHA
                LDA     #0
                TAX
                LDA:    _sa_pdp_alignment,X
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #10
                PHA
                FGX2_FARCALL classify
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #20
                PHA
                FGX2_FARCALL classify
                TAY
                PLA
                TYA
                ASL
                STA     _fcc_tmp_b
                PLA
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
                FGX2_RELOC_COUNT 5
