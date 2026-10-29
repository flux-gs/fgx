                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bf_write.c
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
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$FF00
                STA     1,S   ; fccstk d=0 b=1
                LDA     #100
                AND     #$00FF
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                STA     1,S   ; fccstk d=0 b=1
                LDA     #200
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
                AND     #$FF00
                STA     1,S   ; fccstk d=0 b=1
                LDA     #42
                AND     #$00FF
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
