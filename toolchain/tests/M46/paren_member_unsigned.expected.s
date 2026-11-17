                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from paren_member_unsigned.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT a1
a1            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a1_FRAMESIZE
                DO      a1_STKGUARD
                BCC     a1_stkovf
                CMP     _fcc_stkfloor
                BCS     a1_stkok
a1_stkovf       JMP     _fcc_stkoflow
                FIN
a1_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a1_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a1_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a1_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a1_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a1_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a1_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a1_FRAMESIZE   EQU     0
a1_STKGUARD    EQU     0
                FGX2_EXPORT a2
a2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a2_FRAMESIZE
                DO      a2_STKGUARD
                BCC     a2_stkovf
                CMP     _fcc_stkfloor
                BCS     a2_stkok
a2_stkovf       JMP     _fcc_stkoflow
                FIN
a2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a2_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a2_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a2_FRAMESIZE   EQU     0
a2_STKGUARD    EQU     0
                FGX2_EXPORT a3
a3            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a3_FRAMESIZE
                DO      a3_STKGUARD
                BCC     a3_stkovf
                CMP     _fcc_stkfloor
                BCS     a3_stkok
a3_stkovf       JMP     _fcc_stkoflow
                FIN
a3_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a3_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a3_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a3_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a3_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a3_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a3_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a3_FRAMESIZE   EQU     0
a3_STKGUARD    EQU     0
                FGX2_EXPORT a4
a4            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a4_FRAMESIZE
                DO      a4_STKGUARD
                BCC     a4_stkovf
                CMP     _fcc_stkfloor
                BCS     a4_stkok
a4_stkovf       JMP     _fcc_stkoflow
                FIN
a4_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a4_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a4_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a4_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a4_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a4_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a4_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a4_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a4_FRAMESIZE   EQU     0
a4_STKGUARD    EQU     0
                FGX2_EXPORT a5
a5            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a5_FRAMESIZE
                DO      a5_STKGUARD
                BCC     a5_stkovf
                CMP     _fcc_stkfloor
                BCS     a5_stkok
a5_stkovf       JMP     _fcc_stkoflow
                FIN
a5_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     g+4
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a5_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a5_FRAMESIZE   EQU     0
a5_STKGUARD    EQU     0
                FGX2_EXPORT a6
a6            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a6_FRAMESIZE
                DO      a6_STKGUARD
                BCC     a6_stkovf
                CMP     _fcc_stkfloor
                BCS     a6_stkok
a6_stkovf       JMP     _fcc_stkoflow
                FIN
a6_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a6_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a6_FRAMESIZE   EQU     0
a6_STKGUARD    EQU     0
                FGX2_EXPORT a7
a7            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a7_FRAMESIZE
                DO      a7_STKGUARD
                BCC     a7_stkovf
                CMP     _fcc_stkfloor
                BCS     a7_stkok
a7_stkovf       JMP     _fcc_stkoflow
                FIN
a7_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a7_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a7_FRAMESIZE   EQU     0
a7_STKGUARD    EQU     0
                FGX2_EXPORT a8
a8            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a8_FRAMESIZE
                DO      a8_STKGUARD
                BCC     a8_stkovf
                CMP     _fcc_stkfloor
                BCS     a8_stkok
a8_stkovf       JMP     _fcc_stkoflow
                FIN
a8_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a8_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a8_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a8_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a8_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a8_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a8_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #12
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a8_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a8_FRAMESIZE   EQU     0
a8_STKGUARD    EQU     0
                FGX2_EXPORT a9
a9            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a9_FRAMESIZE
                DO      a9_STKGUARD
                BCC     a9_stkovf
                CMP     _fcc_stkfloor
                BCS     a9_stkok
a9_stkovf       JMP     _fcc_stkoflow
                FIN
a9_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a9_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a9_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a9_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a9_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a9_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a9_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a9_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a9_FRAMESIZE   EQU     0
a9_STKGUARD    EQU     0
                FGX2_EXPORT a10
a10            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a10_FRAMESIZE
                DO      a10_STKGUARD
                BCC     a10_stkovf
                CMP     _fcc_stkfloor
                BCS     a10_stkok
a10_stkovf       JMP     _fcc_stkoflow
                FIN
a10_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a10_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a10_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a10_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a10_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a10_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a10_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a10_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a10_FRAMESIZE   EQU     0
a10_STKGUARD    EQU     0
                FGX2_EXPORT a13
a13            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a13_FRAMESIZE
                DO      a13_STKGUARD
                BCC     a13_stkovf
                CMP     _fcc_stkfloor
                BCS     a13_stkok
a13_stkovf       JMP     _fcc_stkoflow
                FIN
a13_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a13_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a13_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a13_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a13_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a13_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a13_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #a13_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a13_FRAMESIZE   EQU     0
a13_STKGUARD    EQU     0
                FGX2_EXPORT a11
a11            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a11_FRAMESIZE
                DO      a11_STKGUARD
                BCC     a11_stkovf
                CMP     _fcc_stkfloor
                BCS     a11_stkok
a11_stkovf       JMP     _fcc_stkoflow
                FIN
a11_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a11_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a11_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a11_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a11_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a11_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a11_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                LDX     #0
                STX     _fcc_long_hi
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_add
                TAY
                TSC
                CLC
                ADC     #a11_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a11_FRAMESIZE   EQU     0
a11_STKGUARD    EQU     0
                FGX2_EXPORT a12
a12            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #a12_FRAMESIZE
                DO      a12_STKGUARD
                BCC     a12_stkovf
                CMP     _fcc_stkfloor
                BCS     a12_stkok
a12_stkovf       JMP     _fcc_stkoflow
                FIN
a12_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+a12_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+a12_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+a12_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+a12_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+a12_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+a12_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #8
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                TAY
                TSC
                CLC
                ADC     #a12_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
a12_FRAMESIZE   EQU     0
a12_STKGUARD    EQU     0
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FF80
                STA     3,S   ; fccstk d=0 b=3
                TAY
                LDA     _fcc_long_hi
                STA     5,S   ; fccstk d=0 b=5
                TYA
                LDA     #65408
                STA     g+4
                LDA     #65408
                STA     g+12
                LDA     #128
                SEP     #$20
                MX      %10
                STA     g+6
                REP     #$20
                MX      %00
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     g+8
                TAY
                LDA     _fcc_long_hi
                STA     g+10
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     g+14
                TAY
                LDA     _fcc_ptr+2
                STA     g+16
                TYA
                LDA     #1
                ASL
                ASL
                ASL
                INC
                ASL
                CLC
                ADC     #arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #65408
                LDY     #4
                STA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a1
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L0
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a2
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L1
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a3
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L2
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a4
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L3
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L3
                FGX2_FARCALL a5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L4
                FGX2_FARCALL a6
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L5
                FGX2_FARCALL a7
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a8
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a9
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L8
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a10
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L9
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a11
                PLY
                PLY
                LDX     #128
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _paren_member_unsigned_L10
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a13
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=4 b=3
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
                BEQ     _paren_member_unsigned_L11
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #3
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L11
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL a12
                PLY
                PLY
                LDX     #65408
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _paren_member_unsigned_L12
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #6
                STA     1,S   ; fccstk d=0 b=1
_paren_member_unsigned_L12
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
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 28
