                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from inc_via_ptr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT inc
inc            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #inc_FRAMESIZE
                DO      inc_STKGUARD
                BCC     inc_stkovf
                CMP     _fcc_stkfloor
                BCS     inc_stkok
inc_stkovf       JMP     _fcc_stkoflow
                FIN
inc_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+inc_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+inc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+inc_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+inc_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+inc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+inc_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      6+inc_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+inc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+inc_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+inc_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+inc_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+inc_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #inc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
inc_FRAMESIZE   EQU     0
inc_STKGUARD    EQU     0
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
                LDA     #41
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
                FGX2_FARCALL inc
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
