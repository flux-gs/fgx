                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_promote_scalar.c
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
_p33_promote_scalar_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #520
                BVC     _p33_promote_scalar_L3
                EOR     #$8000
_p33_promote_scalar_L3
                BPL     _p33_promote_scalar_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
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
_p33_promote_scalar_L1
                INC     _fcc_img0
                BRA     _p33_promote_scalar_L0
_p33_promote_scalar_L2
                LDA     #100
                STA     _fcc_img1
                LDA     #200
                STA     _fcc_img2
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img2
                STA     _fcc_img3
                TAX
                CMP     #300
                BEQ     _p33_promote_scalar_L4
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
_p33_promote_scalar_L4
                LDA     _fcc_img1
                ASL
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img3
                TAX
                CMP     #800
                BEQ     _p33_promote_scalar_L5
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
_p33_promote_scalar_L5
                LDA     _fcc_img3
                STA     _fcc_img2
                STA     _fcc_img1
                TAX
                CMP     #800
                BNE     _p33_promote_scalar_L7
                LDA     _fcc_img2
                TAX
                CMP     #800
                BNE     _p33_promote_scalar_L7
                LDA     #0
                BRA     _p33_promote_scalar_L8
_p33_promote_scalar_L7
                LDA     #1
_p33_promote_scalar_L8
                CMP     #0
                BEQ     _p33_promote_scalar_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_promote_scalar_L6
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BNE     _p33_promote_scalar_L10
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                PHA
                LDA     #519
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BNE     _p33_promote_scalar_L10
                LDA     #0
                BRA     _p33_promote_scalar_L11
_p33_promote_scalar_L10
                LDA     #1
_p33_promote_scalar_L11
                CMP     #0
                BEQ     _p33_promote_scalar_L9
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_promote_scalar_L9
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     528
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 2
