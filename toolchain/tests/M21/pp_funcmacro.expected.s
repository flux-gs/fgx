                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pp_funcmacro.c
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
                LDA     #20
                CLC
                ADC     #21
                STA     _fcc_img0
                LDA     #20
                ASL
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _pp_funcmacro_L2
                EOR     #$8000
_pp_funcmacro_L2
                BPL     _pp_funcmacro_L0
                LDA     #20
                ASL
                BRA     _pp_funcmacro_L1
_pp_funcmacro_L0
                LDA     _fcc_img0
_pp_funcmacro_L1
                STA     3,S   ; fccstk d=0 b=3
                TAX
                INC
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
