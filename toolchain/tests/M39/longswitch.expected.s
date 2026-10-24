                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longswitch.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _longswitch_pick
_longswitch_pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_longswitch_pick_FRAMESIZE
                DO      _longswitch_pick_STKGUARD
                BCC     _longswitch_pick_stkovf
                CMP     _fcc_stkfloor
                BCS     _longswitch_pick_stkok
_longswitch_pick_stkovf       JMP     _fcc_stkoflow
                FIN
_longswitch_pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_longswitch_pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_longswitch_pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_longswitch_pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_longswitch_pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_longswitch_pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_longswitch_pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                CMP     #17229
                BNE     _longswitch_L7
                LDA     _fcc_long_b_lo
                CMP     #25965
                BEQ     _longswitch_L1
_longswitch_L7
                LDA     _fcc_long_hi
                CMP     #21837
                BNE     _longswitch_L8
                LDA     _fcc_long_b_lo
                CMP     #25965
                BEQ     _longswitch_L2
_longswitch_L8
                LDA     _fcc_long_hi
                CMP     #21364
                BNE     _longswitch_L9
                LDA     _fcc_long_b_lo
                CMP     #27507
                BEQ     _longswitch_L3
_longswitch_L9
                LDA     _fcc_long_hi
                CMP     #0
                BNE     _longswitch_L10
                LDA     _fcc_long_b_lo
                CMP     #5
                BEQ     _longswitch_L4
_longswitch_L10
                LDA     _fcc_long_hi
                CMP     #65535
                BNE     _longswitch_L11
                LDA     _fcc_long_b_lo
                CMP     #65534
                BEQ     _longswitch_L5
_longswitch_L11
                BRA     _longswitch_L6
_longswitch_L1
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_longswitch_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_longswitch_L2
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #_longswitch_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_longswitch_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #_longswitch_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_longswitch_L4
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #_longswitch_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_longswitch_L5
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #_longswitch_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_longswitch_L6
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #_longswitch_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_longswitch_L0
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_longswitch_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_longswitch_pick_FRAMESIZE   EQU     0
_longswitch_pick_STKGUARD    EQU     0
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
                LDA     #$FFFE
                STA     1,S   ; fccstk d=0 b=1
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$656D
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #67
                JSR     _fcc_long_from_int
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #77
                JSR     _fcc_long_from_int
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #101
                JSR     _fcc_long_from_int
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #109
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _longswitch_pick
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #1
                BEQ     _longswitch_L12
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
_longswitch_L12
                LDA     #85
                JSR     _fcc_long_from_int
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #77
                JSR     _fcc_long_from_int
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #101
                JSR     _fcc_long_from_int
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #109
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _longswitch_pick
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #2
                BEQ     _longswitch_L13
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
_longswitch_L13
                LDA     #83
                JSR     _fcc_long_from_int
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #116
                JSR     _fcc_long_from_int
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #107
                JSR     _fcc_long_from_int
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #115
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _longswitch_pick
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #4
                BEQ     _longswitch_L14
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
_longswitch_L14
                LDA     #5
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _longswitch_pick
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #8
                BEQ     _longswitch_L15
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
_longswitch_L15
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _longswitch_pick
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #16
                BEQ     _longswitch_L16
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
_longswitch_L16
                LDA     #65
                JSR     _fcc_long_from_int
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_long_hi
                LDA     #0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #78
                JSR     _fcc_long_from_int
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #78
                JSR     _fcc_long_from_int
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                ASL
                ROL     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #79
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_or
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _longswitch_pick
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #32
                BEQ     _longswitch_L17
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
_longswitch_L17
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _longswitch_pick
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                TXA
                CMP     #32
                BEQ     _longswitch_L18
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
_longswitch_L18
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 10
