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
                CMP     #0
                BMI     *+5
                BRL     _seekrw_L0
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
                TSC
                SEC
                SBC     #_seekrw_mk35_FRAMESIZE
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img0
_seekrw_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #35
                BVC     _seekrw_L4
                EOR     #$8000
_seekrw_L4
                BMI     *+5
                BRL     _seekrw_L3
                LDA     #buf
                PHA
                LDA     _fcc_img0
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
                INC     _fcc_img0
                BRL     _seekrw_L1
_seekrw_L3
                LDA     _fcc_img0
                STA     3,S   ; fccstk d=0 b=3
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
                CMP     #0
                BMI     *+5
                BRL     _seekrw_L5
                LDA     #$FFFF
                TAY
                TSC
                CLC
                ADC     #_seekrw_mk35_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
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
                ADC     #_seekrw_mk35_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_seekrw_mk35_FRAMESIZE   EQU     4
_seekrw_mk35_STKGUARD    EQU     0
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
                CMP     #0
                BMI     *+5
                BRL     _seekrw_L6
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
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
                STA     7,S   ; fccstk d=0 b=7
                STA     _fcc_img0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_img1
_seekrw_L7
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #32
                BVC     _seekrw_L10
                EOR     #$8000
_seekrw_L10
                BMI     *+5
                BRL     _seekrw_L9
                LDA     _fcc_img0
                TAX
                LDA:    buf,X
                AND     #$00FF
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L11
                LDA     #0
                STA     _fcc_img1
_seekrw_L11
_seekrw_L8
                INC     _fcc_img0
                BRL     _seekrw_L7
_seekrw_L9
                LDA     _fcc_img0
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_img1
                STA     11,S   ; fccstk d=0 b=11
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #35
                BEQ     *+5
                BRL     _seekrw_L17
                LDA     11,S   ; fccstk d=0 b=11
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L17
                LDA     #1
                BRL     _seekrw_L18
_seekrw_L17
                LDA     #0
_seekrw_L18
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L15
                LDA     #32
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #88
                BEQ     *+5
                BRL     _seekrw_L15
                LDA     #1
                BRL     _seekrw_L16
_seekrw_L15
                LDA     #0
_seekrw_L16
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L13
                LDA     #34
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _seekrw_L13
                LDA     #1
                BRL     _seekrw_L14
_seekrw_L13
                LDA     #0
_seekrw_L14
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L12
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
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
                TXA
                CMP     #35
                BEQ     *+5
                BRL     _seekrw_L24
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #48
                BEQ     *+5
                BRL     _seekrw_L24
                LDA     #1
                BRL     _seekrw_L25
_seekrw_L24
                LDA     #0
_seekrw_L25
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L22
                LDA     #7
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #55
                BEQ     *+5
                BRL     _seekrw_L22
                LDA     #1
                BRL     _seekrw_L23
_seekrw_L22
                LDA     #0
_seekrw_L23
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L20
                LDA     #8
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _seekrw_L20
                LDA     #1
                BRL     _seekrw_L21
_seekrw_L20
                LDA     #0
_seekrw_L21
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L19
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #2
                STA     1,S   ; fccstk d=0 b=1
_seekrw_L19
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
                STA     7,S   ; fccstk d=0 b=7
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
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _seekrw_L27
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
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _seekrw_L27
                LDA     #1
                BRL     _seekrw_L28
_seekrw_L27
                LDA     #0
_seekrw_L28
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L26
                LDA     #1
                STA     7,S   ; fccstk d=0 b=7
                BRL     _seekrw_L29
_seekrw_L26
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
_seekrw_L29
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
                LDA     7,S   ; fccstk d=0 b=7
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L37
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #35
                BEQ     *+5
                BRL     _seekrw_L37
                LDA     #1
                BRL     _seekrw_L38
_seekrw_L37
                LDA     #0
_seekrw_L38
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L35
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #56
                BEQ     *+5
                BRL     _seekrw_L35
                LDA     #1
                BRL     _seekrw_L36
_seekrw_L35
                LDA     #0
_seekrw_L36
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L33
                LDA     #7
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #102
                BEQ     *+5
                BRL     _seekrw_L33
                LDA     #1
                BRL     _seekrw_L34
_seekrw_L33
                LDA     #0
_seekrw_L34
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L31
                LDA     #8
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _seekrw_L31
                LDA     #1
                BRL     _seekrw_L32
_seekrw_L31
                LDA     #0
_seekrw_L32
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L30
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
_seekrw_L30
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
                STA     7,S   ; fccstk d=0 b=7
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
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                TXA
                CMP     #16
                BEQ     *+5
                BRL     _seekrw_L42
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _seekrw_L42
                LDA     #1
                BRL     _seekrw_L43
_seekrw_L42
                LDA     #0
_seekrw_L43
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L40
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
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _seekrw_L40
                LDA     #1
                BRL     _seekrw_L41
_seekrw_L40
                LDA     #0
_seekrw_L41
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L39
                LDA     #1
                STA     7,S   ; fccstk d=0 b=7
                BRL     _seekrw_L44
_seekrw_L39
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
_seekrw_L44
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
                CMP     #0
                BEQ     *+5
                BRL     _seekrw_L46
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
                TXA
                CMP     #8
                BEQ     *+5
                BRL     _seekrw_L46
                LDA     #0
                BRL     _seekrw_L47
_seekrw_L46
                LDA     #1
_seekrw_L47
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L45
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
_seekrw_L45
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
                LDA     7,S   ; fccstk d=0 b=7
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L59
                LDA     5,S   ; fccstk d=0 b=5
                TAX
                TXA
                CMP     #35
                BEQ     *+5
                BRL     _seekrw_L59
                LDA     #1
                BRL     _seekrw_L60
_seekrw_L59
                LDA     #0
_seekrw_L60
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L57
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #48
                BEQ     *+5
                BRL     _seekrw_L57
                LDA     #1
                BRL     _seekrw_L58
_seekrw_L57
                LDA     #0
_seekrw_L58
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L55
                LDA     #7
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #55
                BEQ     *+5
                BRL     _seekrw_L55
                LDA     #1
                BRL     _seekrw_L56
_seekrw_L55
                LDA     #0
_seekrw_L56
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L53
                LDA     #8
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #73
                BEQ     *+5
                BRL     _seekrw_L53
                LDA     #1
                BRL     _seekrw_L54
_seekrw_L53
                LDA     #0
_seekrw_L54
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L51
                LDA     #15
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #80
                BEQ     *+5
                BRL     _seekrw_L51
                LDA     #1
                BRL     _seekrw_L52
_seekrw_L51
                LDA     #0
_seekrw_L52
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L49
                LDA     #16
                TAX
                LDA:    buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BEQ     *+5
                BRL     _seekrw_L49
                LDA     #1
                BRL     _seekrw_L50
_seekrw_L49
                LDA     #0
_seekrw_L50
                CMP     #0
                BNE     *+5
                BRL     _seekrw_L48
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #8
                STA     1,S   ; fccstk d=0 b=1
_seekrw_L48
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
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 49
