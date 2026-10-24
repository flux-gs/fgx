                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from spawnops.c
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
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #argv_tab
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nm
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #argv_tab
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     #0
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #argv_tab
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nm
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL spawnv
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _spawnops_L1
                EOR     #$8000
_spawnops_L1
                BPL     _spawnops_L0
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_spawnops_L0
                LDA     #0
                PHA
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
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL waitpid
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _spawnops_L2
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #10
                STA     5,S   ; fccstk d=0 b=5
_spawnops_L2
                LDA     3,S   ; fccstk d=0 b=3
                BNE     _spawnops_L3
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #6
                STA     5,S   ; fccstk d=0 b=5
_spawnops_L3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #argv_tab
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_spawnops_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL spawnv
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #$FFFF
                BNE     _spawnops_L4
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_spawnops_L4
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #argv_tab
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nm
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL spawnve
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAX
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _spawnops_L8
                EOR     #$8000
_spawnops_L8
                BPL     _spawnops_L6
                LDA     #0
                PHA
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
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL waitpid
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _spawnops_L6
                LDA     #1
                BRA     _spawnops_L7
_spawnops_L6
                LDA     #0
_spawnops_L7
                CMP     #0
                BEQ     _spawnops_L5
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CLC
                ADC     #8
                STA     5,S   ; fccstk d=0 b=5
_spawnops_L5
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
