                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ss_struct.c
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
                LDA     #40
                STA     gv
                LDA     #30
                STA     1,S   ; fccstk d=0 b=1
                LDA     #5
                SEP     #$20
                MX      %10
                STA     3,S   ; fccstk d=0 b=3
                REP     #$20
                MX      %00
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gv
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_ptr+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                SEC
                SBC     #33
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 2
