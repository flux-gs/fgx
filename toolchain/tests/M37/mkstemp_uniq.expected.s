                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from mkstemp_uniq.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT sameis
sameis            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sameis_FRAMESIZE
                DO      sameis_STKGUARD
                BCC     sameis_stkovf
                CMP     _fcc_stkfloor
                BCS     sameis_stkok
sameis_stkovf       JMP     _fcc_stkoflow
                FIN
sameis_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sameis_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+sameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sameis_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+sameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sameis_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+sameis_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sameis_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sameis_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img0
_mkstemp_uniq_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BEQ     _mkstemp_uniq_L2
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _mkstemp_uniq_L2
                LDA     #1
                BRA     _mkstemp_uniq_L3
_mkstemp_uniq_L2
                LDA     #0
_mkstemp_uniq_L3
                CMP     #0
                BEQ     _mkstemp_uniq_L1
                INC     _fcc_img0
                BRA     _mkstemp_uniq_L0
_mkstemp_uniq_L1
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_eq16
                TAY
                TSC
                CLC
                ADC     #sameis_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sameis_FRAMESIZE   EQU     2
sameis_STKGUARD    EQU     0
                FGX2_EXPORT hasx
hasx            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #hasx_FRAMESIZE
                DO      hasx_STKGUARD
                BCC     hasx_stkovf
                CMP     _fcc_stkfloor
                BCS     hasx_stkok
hasx_stkovf       JMP     _fcc_stkoflow
                FIN
hasx_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+hasx_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+hasx_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+hasx_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
                DO      8+hasx_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+hasx_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+hasx_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img1
_mkstemp_uniq_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img0]
                AND     #$00FF
                BEQ     _mkstemp_uniq_L5
                LDA     [_fcc_img0]
                AND     #$00FF
                TAX
                CMP     #88
                BNE     _mkstemp_uniq_L6
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #hasx_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mkstemp_uniq_L6
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _mkstemp_uniq_L4
_mkstemp_uniq_L5
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #hasx_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
hasx_FRAMESIZE   EQU     0
hasx_STKGUARD    EQU     0
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
                STA     13,S   ; fccstk d=0 b=13
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_mkstemp_uniq_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strcpy
                TSC
                CLC
                ADC     #8
                TCS
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_mkstemp_uniq_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #38
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strcpy
                TSC
                CLC
                ADC     #8
                TCS
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mkstemp
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     9,S   ; fccstk d=0 b=9
                BMI     _mkstemp_uniq_L8
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL hasx
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                BEQ     _mkstemp_uniq_L10
                LDA     #0
                BRA     _mkstemp_uniq_L11
_mkstemp_uniq_L10
                LDA     #1
_mkstemp_uniq_L11
                CMP     #0
                BEQ     _mkstemp_uniq_L8
                LDA     #1
                BRA     _mkstemp_uniq_L9
_mkstemp_uniq_L8
                LDA     #0
_mkstemp_uniq_L9
                CMP     #0
                BEQ     _mkstemp_uniq_L7
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                CLC
                ADC     #12
                STA     13,S   ; fccstk d=0 b=13
_mkstemp_uniq_L7
                LDA     9,S   ; fccstk d=0 b=9
                CMP     #0
                BPL     *+5
                BRL     _mkstemp_uniq_L12
                LDA     #4
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_mkstemp_uniq_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S   ; fccstk d=6 b=9
                PHA
                FGX2_FARCALL write
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #4
                BNE     _mkstemp_uniq_L20
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
                LDA     15,S   ; fccstk d=6 b=9
                PHA
                FGX2_FARCALL lseek
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                BEQ     _mkstemp_uniq_L20
                LDA     #1
                BRA     _mkstemp_uniq_L21
_mkstemp_uniq_L20
                LDA     #0
_mkstemp_uniq_L21
                CMP     #0
                BEQ     _mkstemp_uniq_L18
                LDA     #4
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     15,S   ; fccstk d=6 b=9
                PHA
                FGX2_FARCALL read
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #4
                BNE     _mkstemp_uniq_L18
                LDA     #1
                BRA     _mkstemp_uniq_L19
_mkstemp_uniq_L18
                LDA     #0
_mkstemp_uniq_L19
                CMP     #0
                BEQ     _mkstemp_uniq_L16
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #110
                BNE     _mkstemp_uniq_L16
                LDA     #1
                BRA     _mkstemp_uniq_L17
_mkstemp_uniq_L16
                LDA     #0
_mkstemp_uniq_L17
                CMP     #0
                BEQ     _mkstemp_uniq_L14
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #105
                BNE     _mkstemp_uniq_L14
                LDA     #1
                BRA     _mkstemp_uniq_L15
_mkstemp_uniq_L14
                LDA     #0
_mkstemp_uniq_L15
                CMP     #0
                BEQ     _mkstemp_uniq_L13
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                CLC
                ADC     #10
                STA     13,S   ; fccstk d=0 b=13
_mkstemp_uniq_L13
_mkstemp_uniq_L12
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #38
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mkstemp
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     11,S   ; fccstk d=0 b=11
                BMI     _mkstemp_uniq_L23
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #38
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sameis
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _mkstemp_uniq_L25
                LDA     #0
                BRA     _mkstemp_uniq_L26
_mkstemp_uniq_L25
                LDA     #1
_mkstemp_uniq_L26
                CMP     #0
                BEQ     _mkstemp_uniq_L23
                LDA     #1
                BRA     _mkstemp_uniq_L24
_mkstemp_uniq_L23
                LDA     #0
_mkstemp_uniq_L24
                CMP     #0
                BEQ     _mkstemp_uniq_L22
                LDA     13,S   ; fccstk d=0 b=13
                TAX
                CLC
                ADC     #20
                STA     13,S   ; fccstk d=0 b=13
_mkstemp_uniq_L22
                LDA     9,S   ; fccstk d=0 b=9
                BMI     _mkstemp_uniq_L27
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
_mkstemp_uniq_L27
                LDA     11,S   ; fccstk d=0 b=11
                BMI     _mkstemp_uniq_L28
                LDA     11,S   ; fccstk d=0 b=11
                PHA
                FGX2_FARCALL close
                TAY
                PLA
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #38
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL unlink
                TSC
                CLC
                ADC     #4
                TCS
_mkstemp_uniq_L28
                LDA     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     62
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 17
