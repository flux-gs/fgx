                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from member_ops.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f
f            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f_FRAMESIZE
                DO      f_STKGUARD
                BCC     f_stkovf
                CMP     _fcc_stkfloor
                BCS     f_stkok
f_stkovf       JMP     _fcc_stkoflow
                FIN
f_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     1,S   ; fccstk d=0 b=1
                DO      8+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDA     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                DO      8+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #4
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     5,S   ; fccstk d=0 b=5
                DO      8+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     7,S   ; fccstk d=0 b=7
                DO      8+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #4
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                DEC
                STA     [_fcc_ptr]
                STA     _fcc_tmp_b
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                CLC
                ADC     5,S   ; fccstk d=0 b=5
                CLC
                ADC     7,S   ; fccstk d=0 b=7
                PHA
                LDA     #0
                TAX
                LDA:    buf,X
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      10+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+f_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+f_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+f_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+f_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #f_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f_FRAMESIZE   EQU     8
f_STKGUARD    EQU     0
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
                LDA     #buf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #10
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
                LDA     #buf
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #20
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
                LDA     #5
                STA     S+0
                LDA     #0
                STA     S+2
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
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     S+4
                TAY
                LDA     _fcc_ptr+2
                STA     S+6
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #S
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL f
                TAY
                TSC
                CLC
                ADC     #4
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
