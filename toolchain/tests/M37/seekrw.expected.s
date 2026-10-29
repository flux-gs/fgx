                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from seekrw.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _seekrw_filesize
_seekrw_filesize            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_seekrw_filesize_FRAMESIZE
                DO      _seekrw_filesize_STKGUARD
                BCC     _seekrw_filesize_stkovf
                CMP     _fcc_stkfloor
                BCS     _seekrw_filesize_stkok
_seekrw_filesize_stkovf       JMP     _fcc_stkoflow
                FIN
_seekrw_filesize_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                PHA
                LDA     #0
                PHA
                DO      12+_seekrw_filesize_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_seekrw_filesize_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_seekrw_filesize_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_seekrw_filesize_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_seekrw_filesize_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_seekrw_filesize_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                BPL     _seekrw_L0
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_seekrw_filesize_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_seekrw_L0
                LDA     #2
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL lseek
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                TAY
                TSC
                CLC
                ADC     #_seekrw_filesize_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_seekrw_filesize_FRAMESIZE   EQU     4
_seekrw_filesize_STKGUARD    EQU     0
                FGX2_EXPORT _seekrw_mk35
_seekrw_mk35            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #_seekrw_mk35_FRAMESIZE-2
                DO      _seekrw_mk35_STKGUARD
                BCC     _seekrw_mk35_stkovf
                CMP     _fcc_stkfloor
                BCS     _seekrw_mk35_stkok
_seekrw_mk35_stkovf       JMP     _fcc_stkoflow
                FIN
_seekrw_mk35_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img16
_seekrw_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #35
                BVC     _seekrw_L4
                EOR     #$8000
_seekrw_L4
                BPL     _seekrw_L3
                LDA     #buf
                PHA
                LDA     _fcc_img16
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #97
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
_seekrw_L2
                INC     _fcc_img16
                BRA     _seekrw_L1
_seekrw_L3
                LDA     #420
                PHA
                LDA     #1537
                PHA
                DO      12+_seekrw_mk35_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_seekrw_mk35_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_seekrw_mk35_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+_seekrw_mk35_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_seekrw_mk35_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_seekrw_mk35_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                BPL     _seekrw_L5
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_seekrw_mk35_FRAMESIZE-2
                TCS
                BRA     _seekrw_mk35_bandx
_seekrw_L5
                LDA     #35
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                FGX2_FARCALL write
                TSC
                CLC
                ADC     #8
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_seekrw_mk35_FRAMESIZE-2
                TCS
_seekrw_mk35_bandx
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_seekrw_mk35_FRAMESIZE   EQU     6
_seekrw_mk35_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
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
                STA     1,S   ; fccstk d=0 b=1
                LDA     #420
                PHA
                LDA     #1537
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                BPL     _seekrw_L6
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                BRL     main_bandx
_seekrw_L6
                LDA     #0
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0020
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL lseek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #3
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL write
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     #0
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #64
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL read
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     #1
                STA     11,S   ; fccstk d=0 b=11
                LDA     #0
                STA     _fcc_img16
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_img0
_seekrw_L7
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                SEC
                SBC     #32
                BVC     _seekrw_L10
                EOR     #$8000
_seekrw_L10
                BPL     _seekrw_L9
                LDA     _fcc_img16
                TAX
                LDA:    buf,X
                AND     #$00FF
                CMP     #0
                BEQ     _seekrw_L11
                LDA     #0
                STA     _fcc_img0
_seekrw_L11
_seekrw_L8
                INC     _fcc_img16
                BRA     _seekrw_L7
_seekrw_L9
                LDA     _fcc_img0
                STA     11,S   ; fccstk d=0 b=11
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #35
                BNE     _seekrw_L12
                LDA     11,S   ; fccstk d=0 b=11
                BEQ     _seekrw_L12
                LDA     #32
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #88
                BNE     _seekrw_L12
                LDA     #34
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #90
                BNE     _seekrw_L12
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_seekrw_L12
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _seekrw_mk35
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                PHA
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #0
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL lseek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL write
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _seekrw_filesize
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #64
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL read
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #35
                BNE     _seekrw_L13
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #48
                BNE     _seekrw_L13
                LDA     #7
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #55
                BNE     _seekrw_L13
                LDA     #8
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _seekrw_L13
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_seekrw_L13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _seekrw_mk35
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                PHA
                LDA     #2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #8
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL read
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     _fcc_img16
                LDA     #0
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL lseek
                TSC
                CLC
                ADC     #8
                TCS
                LDA     _fcc_img16
                TAX
                CMP     #8
                BNE     _seekrw_L14
                LDA     #8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S3
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL write
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #8
                BNE     _seekrw_L14
                LDA     #1
                STA     _fcc_img16
                BRA     _seekrw_L15
_seekrw_L14
                LDA     #0
                STA     _fcc_img16
_seekrw_L15
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _seekrw_filesize
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #64
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL read
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     _fcc_img16
                BEQ     _seekrw_L16
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #35
                BNE     _seekrw_L16
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #56
                BNE     _seekrw_L16
                LDA     #7
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #102
                BNE     _seekrw_L16
                LDA     #8
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _seekrw_L16
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_seekrw_L16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _seekrw_mk35
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #0
                PHA
                LDA     #2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #16
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL read
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     _fcc_img16
                LDA     #1
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0008
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL lseek
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_img16
                TAX
                CMP     #16
                BNE     _seekrw_L17
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CMP     #8
                BNE     _seekrw_L17
                LDA     #8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL write
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #8
                BNE     _seekrw_L17
                LDA     #1
                STA     _fcc_img16
                BRA     _seekrw_L18
_seekrw_L17
                LDA     #0
                STA     _fcc_img16
_seekrw_L18
                LDA     #1
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0010
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL lseek
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                BNE     _seekrw_L20
                LDA     #8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL write
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #8
                BEQ     _seekrw_L19
_seekrw_L20
                LDA     #0
                STA     _fcc_img16
_seekrw_L19
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _seekrw_filesize
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL open
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                LDA     #64
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     9,S   ; fccstk d=6 b=3
                PHA
                FGX2_FARCALL read
                TSC
                CLC
                ADC     #8
                TCS
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                LDA     _fcc_img16
                BEQ     _seekrw_L21
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #35
                BNE     _seekrw_L21
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #48
                BNE     _seekrw_L21
                LDA     #7
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #55
                BNE     _seekrw_L21
                LDA     #8
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #73
                BNE     _seekrw_L21
                LDA     #15
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #80
                BNE     _seekrw_L21
                LDA     #16
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                CMP     #97
                BNE     _seekrw_L21
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_seekrw_L21
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_seekrw_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
main_bandx
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 49
