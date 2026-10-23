                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from u_track.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT uret
uret            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #uret_FRAMESIZE
                DO      uret_STKGUARD
                BCC     uret_stkovf
                CMP     _fcc_stkfloor
                BCS     uret_stkok
uret_stkovf       JMP     _fcc_stkoflow
                FIN
uret_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #36864
                TAY
                TSC
                CLC
                ADC     #uret_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
uret_FRAMESIZE   EQU     0
uret_STKGUARD    EQU     0
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
                STA     9,S   ; fccstk d=0 b=9
                LDA     #garr
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #36864
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #36864
                STA     gs+0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                LDA     #1
                ASL
                TAX
                LDA:    garr,X
                TAX
                TXA
                LDX     #256
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _u_track_L0
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CLC
                ADC     #1
                STA     9,S   ; fccstk d=0 b=9
_u_track_L0
                FGX2_FARCALL uret
                TAX
                TXA
                LDX     #256
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _u_track_L1
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CLC
                ADC     #2
                STA     9,S   ; fccstk d=0 b=9
_u_track_L1
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                LDX     #256
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _u_track_L2
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CLC
                ADC     #4
                STA     9,S   ; fccstk d=0 b=9
_u_track_L2
                LDA     #36864
                STA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                LDX     #256
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _u_track_L3
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CLC
                ADC     #8
                STA     9,S   ; fccstk d=0 b=9
_u_track_L3
                LDA     #36864
                STA     1,S   ; fccstk d=0 b=1
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_b_hi
                LDA     _fcc_long_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                LSR
                ROR     _fcc_long_b_hi
                STA     _fcc_long_hi
                LDA     _fcc_long_b_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #144
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _u_track_L4
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CLC
                ADC     #16
                STA     9,S   ; fccstk d=0 b=9
_u_track_L4
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #31
                BEQ     *+5
                BRL     _u_track_L5
                LDA     #42
                BRL     _u_track_L6
_u_track_L5
                LDA     9,S   ; fccstk d=0 b=9
_u_track_L6
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
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
