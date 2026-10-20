                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from g53_bigframe.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT bigframe
bigframe            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bigframe_FRAMESIZE
                DO      bigframe_STKGUARD
                BCC     bigframe_stkovf
                CMP     _fcc_stkfloor
                BCS     bigframe_stkok
bigframe_stkovf       JMP     _fcc_stkoflow
                FIN
bigframe_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
_g53_bigframe_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #300
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _g53_bigframe_L3
                EOR     #$8000
_g53_bigframe_L3
                BMI     *+5
                BRL     _g53_bigframe_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
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
                LDA     #127
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
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
_g53_bigframe_L1
                INC     _fcc_img0
                BRL     _g53_bigframe_L0
_g53_bigframe_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                PHA
                LDA     #50
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                PHA
                LDA     #140
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #127
                STA     _fcc_tmp_b
                TXA
                AND     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                SEC
                SBC     3,S   ; fccstk d=0 b=3
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #bigframe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bigframe_FRAMESIZE   EQU     306
bigframe_STKGUARD    EQU     1
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
                FGX2_FARCALL bigframe
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
