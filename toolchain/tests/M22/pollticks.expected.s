                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pollticks.c
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
_pollticks_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                FGX2_FARCALL pollkey
                TAX
                TXA
                CMP     #0
_pollticks_L2
                BPL     *+5
                BRL     _pollticks_L1
                BRL     _pollticks_L0
_pollticks_L1
                FGX2_FARCALL yield
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _pollticks_L3
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pollticks_L3
                FGX2_FARCALL pollkey
                TAX
                TXA
                CMP     #0
_pollticks_L5
                BPL     *+5
                BRL     _pollticks_L4
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pollticks_L4
                FGX2_FARCALL ticks
                STA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL yield
                FGX2_FARCALL ticks
                SEC
                SBC     1,S   ; fccstk d=0 b=1
                STA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                CMP     #0
_pollticks_L7
                BMI     *+5
                BRL     _pollticks_L6
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pollticks_L6
                LDA     #42
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
                FGX2_RELOC_COUNT 8
