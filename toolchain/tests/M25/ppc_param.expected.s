                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ppc_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT deref2
deref2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #deref2_FRAMESIZE
                DO      deref2_STKGUARD
                BCC     deref2_stkovf
                CMP     _fcc_stkfloor
                BCS     deref2_stkok
deref2_stkovf       JMP     _fcc_stkoflow
                FIN
deref2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+deref2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+deref2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+deref2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+deref2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+deref2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+deref2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #deref2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
deref2_FRAMESIZE   EQU     0
deref2_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL deref2
                PLY
                PLY
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
