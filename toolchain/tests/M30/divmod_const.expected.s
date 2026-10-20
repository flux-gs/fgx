                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from divmod_const.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT p2
p2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #p2_FRAMESIZE
                DO      p2_STKGUARD
                BCC     p2_stkovf
                CMP     _fcc_stkfloor
                BCS     p2_stkok
p2_stkovf       JMP     _fcc_stkoflow
                FIN
p2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+p2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+p2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+p2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LSR
                LSR
                PHA
                DO      8+p2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+p2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+p2_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                AND     #7
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #p2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
p2_FRAMESIZE   EQU     0
p2_STKGUARD    EQU     0
                FGX2_EXPORT np
np            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #np_FRAMESIZE
                DO      np_STKGUARD
                BCC     np_stkovf
                CMP     _fcc_stkfloor
                BCS     np_stkok
np_stkovf       JMP     _fcc_stkoflow
                FIN
np_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+np_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+np_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+np_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDX     #3
                STX     _fcc_tmp_b
                JSR     _fcc_divu16
                PHA
                DO      8+np_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+np_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+np_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                LDX     #5
                STX     _fcc_tmp_b
                JSR     _fcc_modu16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #np_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
np_FRAMESIZE   EQU     0
np_STKGUARD    EQU     0
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
                LDA     #37
                PHA
                FGX2_FARCALL p2
                TAY
                PLA
                TYA
                PHA
                LDA     #37
                PHA
                FGX2_FARCALL np
                TAY
                PLA
                TYA
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
                FGX2_RELOC_COUNT 6
