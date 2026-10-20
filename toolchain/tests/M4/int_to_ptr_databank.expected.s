                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from int_to_ptr_databank.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT reconstitute
reconstitute            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #reconstitute_FRAMESIZE
                DO      reconstitute_STKGUARD
                BCC     reconstitute_stkovf
                CMP     _fcc_stkfloor
                BCS     reconstitute_stkok
reconstitute_stkovf       JMP     _fcc_stkoflow
                FIN
reconstitute_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+reconstitute_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+reconstitute_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+reconstitute_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                JSR     _fcc_bank_for_int
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #reconstitute_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
reconstitute_FRAMESIZE   EQU     0
reconstitute_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PHA
                FGX2_FARCALL reconstitute
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #7
                STA     [_fcc_fpr0]
                LDA     g
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
