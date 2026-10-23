                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from rnd.c
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
                LDA     #1
                PHA
                FGX2_FARCALL srand
                TAY
                PLA
                TYA
                FGX2_FARCALL rand
                TAX
                TXA
                CMP     #16838
                BNE     *+5
                BRL     _rnd_L0
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
_rnd_L0
                FGX2_FARCALL rand
                TAX
                TXA
                CMP     #5758
                BNE     *+5
                BRL     _rnd_L1
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
_rnd_L1
                FGX2_FARCALL rand
                TAX
                TXA
                CMP     #10113
                BNE     *+5
                BRL     _rnd_L2
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
_rnd_L2
                LDA     #7
                PHA
                FGX2_FARCALL srandom
                TAY
                PLA
                TYA
                FGX2_FARCALL random
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4C6C
                STA     _fcc_long_hi
                LDA     #$264E
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _rnd_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_rnd_L3
                FGX2_FARCALL random
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$2A74
                STA     _fcc_long_hi
                LDA     #$5892
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _rnd_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_rnd_L4
                LDA     #42
                PHA
                FGX2_FARCALL srand
                TAY
                PLA
                TYA
                FGX2_FARCALL rand
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                PHA
                FGX2_FARCALL rand
                TAX
                LDA     #5
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_shrs16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                FGX2_FARCALL abs
                TAY
                PLA
                TYA
                LDX     #80
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                TAX
                TXA
                SEC
                SBC     #80
                BVC     _rnd_L6
                EOR     #$8000
_rnd_L6
                BPL     *+5
                BRL     _rnd_L5
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_rnd_L5
                LDA     #$FFF9
                PHA
                FGX2_FARCALL abs
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _rnd_L8
                LDA     #7
                PHA
                FGX2_FARCALL abs
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #7
                BEQ     *+5
                BRL     _rnd_L8
                LDA     #0
                BRL     _rnd_L9
_rnd_L8
                LDA     #1
_rnd_L9
                CMP     #0
                BNE     *+5
                BRL     _rnd_L7
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_rnd_L7
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
                FGX2_RELOC_COUNT 15
