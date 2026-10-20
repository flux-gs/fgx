                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT setp
setp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #setp_FRAMESIZE
                DO      setp_STKGUARD
                BCC     setp_stkovf
                CMP     _fcc_stkfloor
                BCS     setp_stkok
setp_stkovf       JMP     _fcc_stkoflow
                FIN
setp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+setp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+setp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+setp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+setp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+setp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+setp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+setp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+setp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+setp_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     [_fcc_fpr0]
                DO      8+setp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+setp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+setp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+setp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+setp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+setp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      12+setp_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+setp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+setp_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                LDY     #2
                STA     [_fcc_fpr0],Y
                TAY
                TSC
                CLC
                ADC     #setp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
setp_FRAMESIZE   EQU     0
setp_STKGUARD    EQU     0
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
                LDA     #12
                PHA
                LDA     #30
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL setp
                TSC
                CLC
                ADC     #8
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
