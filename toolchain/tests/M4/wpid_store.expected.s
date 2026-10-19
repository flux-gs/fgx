                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from wpid_store.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT setit
setit            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #setit_FRAMESIZE
                DO      setit_STKGUARD
                BCC     setit_stkovf
                CMP     _fcc_stkfloor
                BCS     setit_stkok
setit_stkovf       JMP     _fcc_stkoflow
                FIN
setit_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+setit_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+setit_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+setit_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+setit_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #42
                STA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #setit_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
setit_FRAMESIZE   EQU     0
setit_STKGUARD    EQU     0
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
                STA     1,S   ; fccstk d=0 b=1
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
                FGX2_FARCALL setit
                TSC
                CLC
                ADC     #4
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
