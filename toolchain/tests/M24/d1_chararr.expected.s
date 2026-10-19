                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from d1_chararr.c
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
                LDA     #65
                SEP     #$20
                MX      %10
                STA     1,S   ; fccstk d=0 b=1
                REP     #$20
                MX      %00
                LDA     #66
                SEP     #$20
                MX      %10
                STA     2,S   ; fccstk d=0 b=2
                REP     #$20
                MX      %00
                LDA     #67
                SEP     #$20
                MX      %10
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
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
                FGX2_RELOC_COUNT 2
