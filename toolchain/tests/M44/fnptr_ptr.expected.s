                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fnptr_ptr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT add
add            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add_FRAMESIZE
                DO      add_STKGUARD
                BCC     add_stkovf
                CMP     _fcc_stkfloor
                BCS     add_stkok
add_stkovf       JMP     _fcc_stkoflow
                FIN
add_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                INC
                TAY
                TSC
                CLC
                ADC     #add_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add_FRAMESIZE   EQU     0
add_STKGUARD    EQU     0
                FGX2_EXPORT dbl
dbl            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dbl_FRAMESIZE
                DO      dbl_STKGUARD
                BCC     dbl_stkovf
                CMP     _fcc_stkfloor
                BCS     dbl_stkok
dbl_stkovf       JMP     _fcc_stkoflow
                FIN
dbl_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+dbl_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+dbl_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+dbl_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                TAY
                TSC
                CLC
                ADC     #dbl_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dbl_FRAMESIZE   EQU     0
dbl_STKGUARD    EQU     0
                FGX2_EXPORT neg
neg            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #neg_FRAMESIZE
                DO      neg_STKGUARD
                BCC     neg_stkovf
                CMP     _fcc_stkfloor
                BCS     neg_stkok
neg_stkovf       JMP     _fcc_stkoflow
                FIN
neg_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+neg_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+neg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+neg_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                EOR     #$FFFF
                INC
                TAY
                TSC
                CLC
                ADC     #neg_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
neg_FRAMESIZE   EQU     0
neg_STKGUARD    EQU     0
                FGX2_EXPORT kr
kr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #kr_FRAMESIZE
                DO      kr_STKGUARD
                BCC     kr_stkovf
                CMP     _fcc_stkfloor
                BCS     kr_stkok
kr_stkovf       JMP     _fcc_stkoflow
                FIN
kr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+kr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+kr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+kr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+kr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+kr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+kr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #20
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L0-1
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
_fnptr_ptr_L0
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #kr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
kr_FRAMESIZE   EQU     0
kr_STKGUARD    EQU     1
                FGX2_EXPORT ansi
ansi            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ansi_FRAMESIZE
                DO      ansi_STKGUARD
                BCC     ansi_stkovf
                CMP     _fcc_stkfloor
                BCS     ansi_stkok
ansi_stkovf       JMP     _fcc_stkoflow
                FIN
ansi_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+ansi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ansi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ansi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+ansi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ansi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ansi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #20
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L1-1
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
_fnptr_ptr_L1
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #ansi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ansi_FRAMESIZE   EQU     0
ansi_STKGUARD    EQU     1
                FGX2_EXPORT arr
arr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #arr_FRAMESIZE
                DO      arr_STKGUARD
                BCC     arr_stkovf
                CMP     _fcc_stkfloor
                BCS     arr_stkok
arr_stkovf       JMP     _fcc_stkoflow
                FIN
arr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+arr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+arr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+arr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+arr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+arr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+arr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #20
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L2-1
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
_fnptr_ptr_L2
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #arr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
arr_FRAMESIZE   EQU     0
arr_STKGUARD    EQU     1
                FGX2_EXPORT tdp
tdp            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #tdp_FRAMESIZE
                DO      tdp_STKGUARD
                BCC     tdp_stkovf
                CMP     _fcc_stkfloor
                BCS     tdp_stkok
tdp_stkovf       JMP     _fcc_stkoflow
                FIN
tdp_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+tdp_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+tdp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+tdp_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+tdp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+tdp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+tdp_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L3-1
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
_fnptr_ptr_L3
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                PHA
                DO      10+tdp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+tdp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+tdp_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                DO      8+tdp_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+tdp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+tdp_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                TAY
                DO      10+tdp_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+tdp_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+tdp_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                TYA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L4-1
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
_fnptr_ptr_L4
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #tdp_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
tdp_FRAMESIZE   EQU     0
tdp_STKGUARD    EQU     1
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
                ASL
                ASL
                CLC
                ADC     #t
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     17,S   ; fccstk d=0 b=17
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_ptr
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L7-1
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
_fnptr_ptr_L7
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #2
                BEQ     *+5
                BRL     _fnptr_ptr_L6
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                TAY
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                TYA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L8-1
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
_fnptr_ptr_L8
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #6
                BNE     _fnptr_ptr_L6
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_ptr
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #4
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L9-1
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
_fnptr_ptr_L9
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #5
                BEQ     _fnptr_ptr_L5
_fnptr_ptr_L6
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #7
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L12-1
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
_fnptr_ptr_L12
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #$FFF9
                BNE     _fnptr_ptr_L11
                LDA     #1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PLA
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #5
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L13-1
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
_fnptr_ptr_L13
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #10
                BEQ     _fnptr_ptr_L10
_fnptr_ptr_L11
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L10
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t+4
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gpp
                LDA     _fcc_fpr0+2
                STA     gpp+2
                SEP     #$20
                MX      %10
                LDA     gpp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gpp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #5
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L16-1
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
_fnptr_ptr_L16
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #10
                BNE     _fnptr_ptr_L15
                LDA     #1
                ASL
                ASL
                TAX
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gpp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gpp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #5
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L17-1
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
_fnptr_ptr_L17
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #$FFFB
                BEQ     _fnptr_ptr_L14
_fnptr_ptr_L15
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L14
                SEP     #$20
                MX      %10
                LDA     gi+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gi
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #8
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L20-1
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
_fnptr_ptr_L20
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #16
                BNE     _fnptr_ptr_L19
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #8
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L21-1
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
_fnptr_ptr_L21
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #$FFF8
                BEQ     _fnptr_ptr_L18
_fnptr_ptr_L19
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L18
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     o+2
                TAY
                LDA     _fcc_ptr+2
                STA     o+4
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #o
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     op
                LDA     _fcc_fpr0+2
                STA     op+2
                LDA     o+4
                STA     _fcc_fpr0+2
                LDA     o+2
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #9
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L24-1
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
_fnptr_ptr_L24
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #10
                BNE     _fnptr_ptr_L23
                LDA     o+4
                STA     _fcc_fpr0+2
                LDA     o+2
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #9
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L25-1
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
_fnptr_ptr_L25
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #18
                BEQ     _fnptr_ptr_L22
_fnptr_ptr_L23
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L22
                SEP     #$20
                MX      %10
                LDA     op+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     op
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L28-1
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
_fnptr_ptr_L28
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #2
                BNE     _fnptr_ptr_L27
                SEP     #$20
                MX      %10
                LDA     op+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     op
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L29-1
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
_fnptr_ptr_L29
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #$FFFF
                BEQ     _fnptr_ptr_L26
_fnptr_ptr_L27
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L26
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #t
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL kr
                PLY
                PLY
                TAX
                CMP     #40
                BNE     _fnptr_ptr_L31
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ansi
                PLY
                PLY
                TAX
                CMP     #40
                BNE     _fnptr_ptr_L31
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL arr
                PLY
                PLY
                CMP     #$FFEC
                BEQ     _fnptr_ptr_L30
_fnptr_ptr_L31
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L30
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #t
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL tdp
                PLY
                PLY
                TAX
                CMP     #4
                BEQ     _fnptr_ptr_L32
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L32
                LDA     #2
                ASL
                ASL
                CLC
                ADC     #t
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #3
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L35-1
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
_fnptr_ptr_L35
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #$FFFD
                BNE     _fnptr_ptr_L34
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #4
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L36-1
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
_fnptr_ptr_L36
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #$FFFC
                BEQ     _fnptr_ptr_L33
_fnptr_ptr_L34
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L33
                SEP     #$20
                MX      %10
                LDA     _fnptr_ptr_FA37+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fnptr_ptr_FA37
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fnptr_ptr_FA38+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fnptr_ptr_FA38
                STA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #21
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0
                PHK
                PEA     _fnptr_ptr_L41-1
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
_fnptr_ptr_L41
                PLY
                TAX
                CMP     #42
                BNE     _fnptr_ptr_L40
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                TAY
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                TYA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #2
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fnptr_ptr_L42-1
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
_fnptr_ptr_L42
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                CMP     #4
                BEQ     _fnptr_ptr_L39
_fnptr_ptr_L40
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L39
                LDA     #4
                TAX
                CMP     #4
                BNE     _fnptr_ptr_L44
                LDA     #4
                TAX
                CMP     #4
                BNE     _fnptr_ptr_L44
                LDA     #4
                TAX
                CMP     #4
                BEQ     _fnptr_ptr_L43
_fnptr_ptr_L44
                LDA     17,S   ; fccstk d=0 b=17
                CLC
                ADC     #1
                STA     17,S   ; fccstk d=0 b=17
_fnptr_ptr_L43
                LDA     17,S   ; fccstk d=0 b=17
                BEQ     _fnptr_ptr_L45
                LDA     17,S   ; fccstk d=0 b=17
                BRA     _fnptr_ptr_L46
_fnptr_ptr_L45
                LDA     #42
_fnptr_ptr_L46
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 13
