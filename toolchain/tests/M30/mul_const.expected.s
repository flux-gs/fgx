                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from mul_const.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f
f            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f_FRAMESIZE
                DO      f_STKGUARD
                BCC     f_stkovf
                CMP     _fcc_stkfloor
                BCS     f_stkok
f_stkovf       JMP     _fcc_stkoflow
                FIN
f_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                ASL
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE   EQU     0
f_STKGUARD    EQU     0
                FGX2_EXPORT h
h            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #h_FRAMESIZE
                DO      h_STKGUARD
                BCC     h_stkovf
                CMP     _fcc_stkfloor
                BCS     h_stkok
h_stkovf       JMP     _fcc_stkoflow
                FIN
h_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+h_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+h_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+h_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                TAY
                TSC
                CLC
                ADC     #h_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
h_FRAMESIZE   EQU     0
h_STKGUARD    EQU     0
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
                LDA     #7
                PHA
                FGX2_FARCALL f
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL h
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
