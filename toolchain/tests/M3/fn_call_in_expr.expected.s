                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_call_in_expr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sq
sq            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sq_FRAMESIZE
                DO      sq_STKGUARD
                BCC     sq_stkovf
                CMP     _fcc_stkfloor
                BCS     sq_stkok
sq_stkovf       JMP     _fcc_stkoflow
                FIN
sq_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sq_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sq_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                DO      6+sq_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sq_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                TAY
                TSC
                CLC
                ADC     #sq_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sq_FRAMESIZE   EQU     0
sq_STKGUARD    EQU     0
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
                LDA     #6
                PHA
                FGX2_FARCALL sq
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL sq
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                TXA
                INC
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
