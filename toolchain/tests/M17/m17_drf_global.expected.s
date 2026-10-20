                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from m17_drf_global.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT read_through
read_through            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #read_through_FRAMESIZE
                DO      read_through_STKGUARD
                BCC     read_through_stkovf
                CMP     _fcc_stkfloor
                BCS     read_through_stkok
read_through_stkovf       JMP     _fcc_stkoflow
                FIN
read_through_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+read_through_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+read_through_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+read_through_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+read_through_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+read_through_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+read_through_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAY
                TSC
                CLC
                ADC     #read_through_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
read_through_FRAMESIZE   EQU     0
read_through_STKGUARD    EQU     0
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
                LDA     _fcc_fpr0+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_fpr0
                STA     3,S   ; fccstk d=0 b=3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL read_through
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
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
                FGX2_FARCALL read_through
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     7,S   ; fccstk d=0 b=7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_n
                STA     g_p
                LDA     _fcc_fpr0+2
                STA     g_p+2
                SEP     #$20
                MX      %10
                LDA     g_p+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     g_p
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL read_through
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_n
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL read_through
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
                SEC
                SBC     7,S   ; fccstk d=0 b=7
                TAX
                LDA     #28
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
