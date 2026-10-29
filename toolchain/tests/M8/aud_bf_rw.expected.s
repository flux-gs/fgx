                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from aud_bf_rw.c
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
                AND     #$FFF8
                STA     1,S   ; fccstk d=0 b=1
                LDA     #5
                AND     #$0007
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                AND     #$FF07
                STA     1,S   ; fccstk d=0 b=1
                LDA     #17
                AND     #$001F
                ASL
                ASL
                ASL
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
                AND     #$FF07
                STA     1,S   ; fccstk d=0 b=1
                LDA     #4
                AND     #$001F
                ASL
                ASL
                ASL
                ORA     1,S   ; fccstk d=0 b=1
                STA     1,S   ; fccstk d=0 b=1
                AND     #$0007
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                LSR
                LSR
                LSR
                AND     #$001F
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                AND     #$00FF
                LDX     #7
                STX     _fcc_tmp_b
                JSR     _fcc_divs16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #5
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
