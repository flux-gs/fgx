                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sigsfwd.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fwdb
fwdb            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fwdb_FRAMESIZE
                DO      fwdb_STKGUARD
                BCC     fwdb_stkovf
                CMP     _fcc_stkfloor
                BCS     fwdb_stkok
fwdb_stkovf       JMP     _fcc_stkoflow
                FIN
fwdb_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+fwdb_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwdb_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwdb_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                PHA
                DO      12+fwdb_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwdb_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwdb_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                PHA
                DO      12+fwdb_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwdb_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwdb_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                PHA
                DO      12+fwdb_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwdb_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwdb_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                PHA
                FGX2_FARCALL chk
                TAY
                PLA
                PLA
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #fwdb_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fwdb_FRAMESIZE   EQU     0
fwdb_STKGUARD    EQU     0
                FGX2_EXPORT nar
nar            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #nar_FRAMESIZE
                DO      nar_STKGUARD
                BCC     nar_stkovf
                CMP     _fcc_stkfloor
                BCS     nar_stkok
nar_stkovf       JMP     _fcc_stkoflow
                FIN
nar_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+nar_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+nar_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+nar_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #nar_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
nar_FRAMESIZE   EQU     0
nar_STKGUARD    EQU     0
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
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     #5
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=2 b=1
                PHA
                FGX2_FARCALL nar
                TAY
                PLA
                PLA
                TYA
                TAX
                CMP     #5
                BEQ     _sigsfwd_L0
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
_sigsfwd_L0
                LDA     #0
                PHA
                LDA     #0
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #str
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL fwd
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                TAX
                CMP     #42
                BEQ     _sigsfwd_L1
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
_sigsfwd_L1
                LDA     #0
                PHA
                LDA     #0
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #str
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     11,S   ; fccstk d=8 b=3
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=8 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL fwdb
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
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
                FGX2_EXPORT fwd
fwd            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fwd_FRAMESIZE
                DO      fwd_STKGUARD
                BCC     fwd_stkovf
                CMP     _fcc_stkfloor
                BCS     fwd_stkok
fwd_stkovf       JMP     _fcc_stkoflow
                FIN
fwd_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+fwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwd_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                PHA
                DO      12+fwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwd_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                PHA
                DO      12+fwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwd_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                PHA
                DO      12+fwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fwd_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                PHA
                FGX2_FARCALL chk
                TAY
                PLA
                PLA
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #fwd_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fwd_FRAMESIZE   EQU     0
fwd_STKGUARD    EQU     0
                FGX2_EXPORT chk
chk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #chk_FRAMESIZE
                DO      chk_STKGUARD
                BCC     chk_stkovf
                CMP     _fcc_stkfloor
                BCS     chk_stkok
chk_stkovf       JMP     _fcc_stkoflow
                FIN
chk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+chk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+chk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+chk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+chk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+chk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+chk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
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
                BEQ     _sigsfwd_L2
                DO      12+chk_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+chk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+chk_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+chk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+chk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+chk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #str
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _sigsfwd_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _sigsfwd_L4
                LDA     #1
                BRA     _sigsfwd_L5
_sigsfwd_L4
                LDA     #0
_sigsfwd_L5
                CMP     #0
                BEQ     _sigsfwd_L2
                LDA     #42
                BRA     _sigsfwd_L3
_sigsfwd_L2
                LDA     #7
_sigsfwd_L3
                TAY
                TSC
                CLC
                ADC     #chk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
chk_FRAMESIZE   EQU     0
chk_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 11
