                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from charpack.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fret
fret            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fret_FRAMESIZE
                DO      fret_STKGUARD
                BCC     fret_stkovf
                CMP     _fcc_stkfloor
                BCS     fret_stkok
fret_stkovf       JMP     _fcc_stkoflow
                FIN
fret_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #fret_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fret_FRAMESIZE   EQU     0
fret_STKGUARD    EQU     0
                FGX2_EXPORT take
take            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #take_FRAMESIZE
                DO      take_STKGUARD
                BCC     take_stkovf
                CMP     _fcc_stkfloor
                BCS     take_stkok
take_stkovf       JMP     _fcc_stkoflow
                FIN
take_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+take_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+take_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                AND     #$00FF
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                DO      9+take_FRAMESIZE/256
                TSC
                CLC
                ADC     #9+take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     9+take_FRAMESIZE,S   ; fccstk d=2 b=7 fs
                FIN
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #take_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
take_FRAMESIZE   EQU     0
take_STKGUARD    EQU     0
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
                LDA     #2
                TAX
                CMP     #2
                BEQ     _charpack_L0
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
_charpack_L0
                LDA     #4
                TAX
                CMP     #4
                BEQ     _charpack_L1
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
_charpack_L1
                LDA     #4
                TAX
                CMP     #4
                BEQ     _charpack_L2
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
_charpack_L2
                LDA     #8
                TAX
                CMP     #8
                BEQ     _charpack_L3
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
_charpack_L3
                LDA     #6
                TAX
                CMP     #6
                BEQ     _charpack_L4
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
_charpack_L4
                LDA     #17
                SEP     #$20
                MX      %10
                STA     1,S   ; fccstk d=0 b=1
                REP     #$20
                MX      %00
                LDA     #34
                SEP     #$20
                MX      %10
                STA     2,S   ; fccstk d=0 b=2
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                TAX
                CMP     #17
                BNE     _charpack_L6
                LDA     2,S   ; fccstk d=0 b=2
                AND     #$00FF
                TAX
                CMP     #34
                BEQ     _charpack_L5
_charpack_L6
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
_charpack_L5
                LDA     #51
                SEP     #$20
                MX      %10
                STA     2,S   ; fccstk d=0 b=2
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                TAX
                CMP     #17
                BEQ     _charpack_L7
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
_charpack_L7
                LDA     gcc+0
                AND     #$00FF
                TAX
                CMP     #11
                BNE     _charpack_L9
                LDA     gcc+1
                AND     #$00FF
                TAX
                CMP     #22
                BEQ     _charpack_L8
_charpack_L9
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L8
                LDA     #1
                SEP     #$20
                MX      %10
                STA     gb+0
                REP     #$20
                MX      %00
                LDA     #2
                SEP     #$20
                MX      %10
                STA     gb+1
                REP     #$20
                MX      %00
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     gb+2
                TAY
                LDA     _fcc_long_hi
                STA     gb+4
                TYA
                LDA     #3
                SEP     #$20
                MX      %10
                STA     gb+6
                REP     #$20
                MX      %00
                LDA     gb+0
                AND     #$00FF
                TAX
                CMP     #1
                BNE     _charpack_L11
                LDA     gb+1
                AND     #$00FF
                TAX
                CMP     #2
                BNE     _charpack_L11
                LDA     gb+6
                AND     #$00FF
                TAX
                CMP     #3
                BEQ     _charpack_L10
_charpack_L11
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L10
                LDA     gb+4
                STA     _fcc_long_hi
                LDA     gb+2
                LDX     #4464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _charpack_L12
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L12
                LDA     #0
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #1
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #2
                SEP     #$20
                MX      %10
                LDY     #1
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #3
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #4
                SEP     #$20
                MX      %10
                LDY     #1
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #2
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #5
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #0
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #1
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                TAX
                CMP     #2
                BNE     _charpack_L14
                LDA     #1
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #3
                BNE     _charpack_L14
                LDA     #2
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #5
                BEQ     _charpack_L13
_charpack_L14
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L13
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                TAX
                CMP     #2
                BEQ     _charpack_L15
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L15
                LDA     #9
                SEP     #$20
                MX      %10
                STA     3,S   ; fccstk d=0 b=3
                LDA     _charpack_FA16+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _charpack_FA16
                STA     _fcc_fpr0
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
                LDA     3,S   ; fccstk d=0 b=3
                AND     #$00FF
                TAX
                CMP     #9
                BEQ     _charpack_L17
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L17
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                PHK
                PEA     _charpack_L18-1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                PHA
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
_charpack_L18
                STA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #7
                BEQ     _charpack_L19
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L19
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #2
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #0
_charpack_L21
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _charpack_L21
                FGX2_FARCALL take
                TAY
                PLA
                TYA
                PHA
                LDA     #17
                ASL
                ASL
                CLC
                ADC     #17
                ASL
                TAX
                CLC
                ADC     #51
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _charpack_L20
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_charpack_L20
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
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 5
