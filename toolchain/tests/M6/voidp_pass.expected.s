                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from voidp_pass.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT do_it
do_it            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #do_it_FRAMESIZE
                DO      do_it_STKGUARD
                BCC     do_it_stkovf
                CMP     _fcc_stkfloor
                BCS     do_it_stkok
do_it_stkovf       JMP     _fcc_stkoflow
                FIN
do_it_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+do_it_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+do_it_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+do_it_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+do_it_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+do_it_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+do_it_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     #42
                STA     [_fcc_fpr0]
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #do_it_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
do_it_FRAMESIZE   EQU     0
do_it_STKGUARD    EQU     0
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
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
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
                FGX2_FARCALL do_it
                PLY
                PLY
                PLY
                PLY
                LDA     3,S   ; fccstk d=0 b=3
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
