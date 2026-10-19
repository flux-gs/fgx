                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from krvarptr.c
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
                LDA     #7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_krvarptr_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL msgish
                TAY
                TSC
                CLC
                ADC     #6
                TCS
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
                FGX2_EXPORT msgish
msgish            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #msgish_FRAMESIZE
                DO      msgish_STKGUARD
                BCC     msgish_stkovf
                CMP     _fcc_stkfloor
                BCS     msgish_stkok
msgish_stkovf       JMP     _fcc_stkoflow
                FIN
msgish_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+msgish_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+msgish_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+msgish_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+msgish_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+msgish_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+msgish_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #msgish_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
msgish_FRAMESIZE   EQU     0
msgish_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
