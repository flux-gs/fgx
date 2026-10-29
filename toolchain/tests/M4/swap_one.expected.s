                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from swap_one.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT swap
swap            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #swap_FRAMESIZE
                DO      swap_STKGUARD
                BCC     swap_stkovf
                CMP     _fcc_stkfloor
                BCS     swap_stkok
swap_stkovf       JMP     _fcc_stkoflow
                FIN
swap_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+swap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+swap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                STA     1,S   ; fccstk d=0 b=1
                DO      8+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+swap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+swap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                DO      10+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+swap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_ptr
                DO      12+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+swap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                STA     [_fcc_fpr0]
                DO      12+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+swap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+swap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+swap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+swap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     [_fcc_fpr0]
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #swap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
swap_FRAMESIZE   EQU     2
swap_STKGUARD    EQU     0
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
                STA     1,S   ; fccstk d=0 b=1
                LDA     #42
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
                FGX2_FARCALL swap
                PLY
                PLY
                PLY
                PLY
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
