                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sigsover.c
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
                PHA
                LDA     #5
                PHA
                FGX2_FARCALL opt
                TAY
                PLA
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
                FGX2_EXPORT opt
opt            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #opt_FRAMESIZE
                DO      opt_STKGUARD
                BCC     opt_stkovf
                CMP     _fcc_stkfloor
                BCS     opt_stkok
opt_stkovf       JMP     _fcc_stkoflow
                FIN
opt_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+opt_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+opt_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+opt_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #37
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #opt_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
opt_FRAMESIZE   EQU     0
opt_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
