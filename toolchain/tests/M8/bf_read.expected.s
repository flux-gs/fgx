                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bf_read.c
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
                LDA     #7
                STA     _fcc_tmp_b
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$FFF8
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_tmp_b
                AND     #$0007
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #21
                STA     _fcc_tmp_b
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$FF07
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_tmp_b
                AND     #$001F
                ASL
                ASL
                ASL
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                LDA     #6
                STA     _fcc_tmp_b
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_tmp_b
                AND     #$00FF
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                LSR
                LSR
                LSR
                AND     #$001F
                ASL
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
                FGX2_RELOC_COUNT 2
