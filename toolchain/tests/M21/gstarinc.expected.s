                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from gstarinc.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT test
test            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #test_FRAMESIZE
                DO      test_STKGUARD
                BCC     test_stkovf
                CMP     _fcc_stkfloor
                BCS     test_stkok
test_stkovf       JMP     _fcc_stkoflow
                FIN
test_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+test_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+test_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+test_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+test_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+test_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+test_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                INC
                DO      6+test_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+test_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+test_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #test_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
test_FRAMESIZE   EQU     0
test_STKGUARD    EQU     0
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
                LDA     g_msg+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     g_msg
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL test
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
