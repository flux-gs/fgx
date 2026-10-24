                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from incstepfor.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sumto
sumto            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sumto_FRAMESIZE
                DO      sumto_STKGUARD
                BCC     sumto_stkovf
                CMP     _fcc_stkfloor
                BCS     sumto_stkok
sumto_stkovf       JMP     _fcc_stkoflow
                FIN
sumto_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sumto_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sumto_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sumto_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img1
                LDA     #1
                STA     _fcc_img0
_incstepfor_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _incstepfor_L3
                EOR     #$8000
_incstepfor_L3
                BMI     _incstepfor_L2
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img0
                STA     _fcc_img1
_incstepfor_L1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _incstepfor_L0
_incstepfor_L2
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #sumto_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sumto_FRAMESIZE   EQU     4
sumto_STKGUARD    EQU     0
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
                LDA     #5
                PHA
                FGX2_FARCALL sumto
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #15
                BEQ     _incstepfor_L4
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
_incstepfor_L4
                LDA     #10
                PHA
                FGX2_FARCALL sumto
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #55
                BEQ     _incstepfor_L5
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
_incstepfor_L5
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
