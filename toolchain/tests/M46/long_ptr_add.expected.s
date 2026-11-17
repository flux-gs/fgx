                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from long_ptr_add.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT viaptr
viaptr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #viaptr_FRAMESIZE
                DO      viaptr_STKGUARD
                BCC     viaptr_stkovf
                CMP     _fcc_stkfloor
                BCS     viaptr_stkok
viaptr_stkovf       JMP     _fcc_stkoflow
                FIN
viaptr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+viaptr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+viaptr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+viaptr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+viaptr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+viaptr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+viaptr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
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
                ADC     #viaptr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
viaptr_FRAMESIZE   EQU     0
viaptr_STKGUARD    EQU     0
                FGX2_EXPORT parenlong
parenlong            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #parenlong_FRAMESIZE
                DO      parenlong_STKGUARD
                BCC     parenlong_stkovf
                CMP     _fcc_stkfloor
                BCS     parenlong_stkok
parenlong_stkovf       JMP     _fcc_stkoflow
                FIN
parenlong_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+parenlong_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+parenlong_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+parenlong_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+parenlong_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+parenlong_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+parenlong_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LDX     #0
                STX     _fcc_long_hi
                TAY
                TSC
                CLC
                ADC     #parenlong_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
parenlong_FRAMESIZE   EQU     0
parenlong_STKGUARD    EQU     0
                FGX2_EXPORT parencmp
parencmp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #parencmp_FRAMESIZE
                DO      parencmp_STKGUARD
                BCC     parencmp_stkovf
                CMP     _fcc_stkfloor
                BCS     parencmp_stkok
parencmp_stkovf       JMP     _fcc_stkoflow
                FIN
parencmp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+parencmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+parencmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+parencmp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+parencmp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+parencmp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+parencmp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                TAX
                LDA     #128
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_geu16
                TAY
                TSC
                CLC
                ADC     #parencmp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
parencmp_FRAMESIZE   EQU     0
parencmp_STKGUARD    EQU     0
                FGX2_EXPORT parenshift
parenshift            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #parenshift_FRAMESIZE
                DO      parenshift_STKGUARD
                BCC     parenshift_stkovf
                CMP     _fcc_stkfloor
                BCS     parenshift_stkok
parenshift_stkovf       JMP     _fcc_stkoflow
                FIN
parenshift_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+parenshift_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+parenshift_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+parenshift_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+parenshift_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+parenshift_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+parenshift_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                LSR
                TAY
                TSC
                CLC
                ADC     #parenshift_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
parenshift_FRAMESIZE   EQU     0
parenshift_STKGUARD    EQU     0
                FGX2_EXPORT plain
plain            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #plain_FRAMESIZE
                DO      plain_STKGUARD
                BCC     plain_stkovf
                CMP     _fcc_stkfloor
                BCS     plain_stkok
plain_stkovf       JMP     _fcc_stkoflow
                FIN
plain_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+plain_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+plain_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+plain_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+plain_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+plain_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+plain_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      14+plain_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+plain_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+plain_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
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
                ADC     #plain_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
plain_FRAMESIZE   EQU     0
plain_STKGUARD    EQU     0
                FGX2_EXPORT viaglobal
viaglobal            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #viaglobal_FRAMESIZE
                DO      viaglobal_STKGUARD
                BCC     viaglobal_stkovf
                CMP     _fcc_stkfloor
                BCS     viaglobal_stkok
viaglobal_stkovf       JMP     _fcc_stkoflow
                FIN
viaglobal_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     la+2
                STA     _fcc_long_hi
                LDA     la
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     us
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
                ADC     #viaglobal_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
viaglobal_FRAMESIZE   EQU     0
viaglobal_STKGUARD    EQU     0
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
                LDA     #65408
                STA     g+4
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
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #65408
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_add
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #65408
                PHA
                LDA     #$005F
                STA     _fcc_long_hi
                LDA     #$6B00
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL plain
                PLY
                PLY
                PLY
                LDX     #27264
                STX     _fcc_long_b_lo
                LDX     #96
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_ptr_add_L0
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_long_ptr_add_L0
                FGX2_FARCALL viaglobal
                LDX     #27264
                STX     _fcc_long_b_lo
                LDX     #96
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_ptr_add_L1
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_long_ptr_add_L1
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
                FGX2_FARCALL viaptr
                PLY
                PLY
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=4 b=5
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
                BEQ     _long_ptr_add_L2
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #10
                STA     9,S   ; fccstk d=0 b=9
_long_ptr_add_L2
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
                FGX2_FARCALL parenlong
                PLY
                PLY
                LDX     #65408
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _long_ptr_add_L3
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #4
                STA     9,S   ; fccstk d=0 b=9
_long_ptr_add_L3
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
                FGX2_FARCALL parencmp
                PLY
                PLY
                CMP     #0
                BEQ     _long_ptr_add_L4
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #4
                STA     9,S   ; fccstk d=0 b=9
_long_ptr_add_L4
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
                FGX2_FARCALL parenshift
                PLY
                PLY
                TAX
                CMP     #255
                BNE     _long_ptr_add_L5
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                CLC
                ADC     #4
                STA     9,S   ; fccstk d=0 b=9
_long_ptr_add_L5
                LDA     9,S   ; fccstk d=0 b=9
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
                FGX2_RELOC_COUNT 14
