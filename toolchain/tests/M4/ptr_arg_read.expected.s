                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_arg_read.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT deref
deref            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #deref_FRAMESIZE
                DO      deref_STKGUARD
                BCC     deref_stkovf
                CMP     _fcc_stkfloor
                BCS     deref_stkok
deref_stkovf       JMP     _fcc_stkoflow
                FIN
deref_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+deref_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+deref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+deref_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+deref_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+deref_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+deref_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAY
                TSC
                CLC
                ADC     #deref_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
deref_FRAMESIZE   EQU     0
deref_STKGUARD    EQU     0
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
                LDA     #42
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
                FGX2_FARCALL deref
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
