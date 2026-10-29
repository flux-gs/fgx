                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from g53_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT bigframe_p
bigframe_p            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bigframe_p_FRAMESIZE
                DO      bigframe_p_STKGUARD
                BCC     bigframe_p_stkovf
                CMP     _fcc_stkfloor
                BCS     bigframe_p_stkok
bigframe_p_stkovf       JMP     _fcc_stkoflow
                FIN
bigframe_p_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
_g53_param_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #300
                BVC     _g53_param_L3
                EOR     #$8000
_g53_param_L3
                BMI     *+5
                BRL     _g53_param_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                TAX
                TXA
                AND     #127
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
_g53_param_L1
                INC     _fcc_img0
                BRL     _g53_param_L0
_g53_param_L2
                DO      6+bigframe_p_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+bigframe_p_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+bigframe_p_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     #50
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                TXA
                SEC
                SBC     #12
                TAY
                TSC
                CLC
                ADC     #bigframe_p_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bigframe_p_FRAMESIZE   EQU     302
bigframe_p_STKGUARD    EQU     1
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
                LDA     #4
                PHA
                FGX2_FARCALL bigframe_p
                TAY
                PLA
                TYA
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
                FGX2_RELOC_COUNT 4
