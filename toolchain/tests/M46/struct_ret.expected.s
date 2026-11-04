                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_ret.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT mk
mk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mk_FRAMESIZE
                DO      mk_STKGUARD
                BCC     mk_stkovf
                CMP     _fcc_stkfloor
                BCS     mk_stkok
mk_stkovf       JMP     _fcc_stkoflow
                FIN
mk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+mk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                DO      12+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+mk_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     3,S   ; fccstk d=0 b=3
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     #$86A0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                DO      8+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+mk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+mk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+mk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+mk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
_struct_ret_L0
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_ret_L0
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #mk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mk_FRAMESIZE   EQU     8
mk_STKGUARD    EQU     0
                FGX2_EXPORT sum
sum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum_FRAMESIZE
                DO      sum_STKGUARD
                BCC     sum_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_stkok
sum_stkovf       JMP     _fcc_stkoflow
                FIN
sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CMP     #0
                BNE     _struct_ret_L1
                LDA     #0
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
                DO      8+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
_struct_ret_L2
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_ret_L2
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_struct_ret_L1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      14+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+sum_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                TAX
                DEC
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL sum
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #6
_struct_ret_L3
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_ret_L3
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                DO      12+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sum_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                DO      8+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
_struct_ret_L4
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_ret_L4
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_FRAMESIZE   EQU     24
sum_STKGUARD    EQU     1
                FGX2_EXPORT viap
viap            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #viap_FRAMESIZE
                DO      viap_STKGUARD
                BCC     viap_stkovf
                CMP     _fcc_stkfloor
                BCS     viap_stkok
viap_stkovf       JMP     _fcc_stkoflow
                FIN
viap_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+viap_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+viap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+viap_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+viap_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+viap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+viap_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                DO      8+viap_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+viap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+viap_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+viap_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+viap_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+viap_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
_struct_ret_L5
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_ret_L5
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #viap_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
viap_FRAMESIZE   EQU     0
viap_STKGUARD    EQU     0
                FGX2_EXPORT viacast
viacast            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #viacast_FRAMESIZE
                DO      viacast_STKGUARD
                BCC     viacast_stkovf
                CMP     _fcc_stkfloor
                BCS     viacast_stkok
viacast_stkovf       JMP     _fcc_stkoflow
                FIN
viacast_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #10+viacast_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DO      8+viacast_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+viacast_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+viacast_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr1+2
                DO      6+viacast_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+viacast_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+viacast_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr1
                LDY     #6
_struct_ret_L6
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_ret_L6
                LDA     _fcc_fpr1
                STA     _fcc_fpr0
                LDA     _fcc_fpr1+2
                STA     _fcc_fpr0+2
                TAY
                TSC
                CLC
                ADC     #viacast_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
viacast_FRAMESIZE   EQU     0
viacast_STKGUARD    EQU     0
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
                PHA
                LDA     #1
                PHA
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
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
                LDA     [_fcc_fpr0]
                PHA
                LDA     #4
                PHA
                LDA     #3
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                CMP     #5
                BEQ     _struct_ret_L7
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
_struct_ret_L7
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #20
                PHA
                LDA     #10
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #30
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #6
_struct_ret_L8
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_ret_L8
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #10
                BNE     _struct_ret_L10
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #20
                BNE     _struct_ret_L10
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #34464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_ret_L9
_struct_ret_L10
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
_struct_ret_L9
                SEP     #$20
                MX      %10
                LDA     _struct_ret_FA11+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _struct_ret_FA11
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #6
                PHA
                LDA     #5
                PHA
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
                LDA     9,S
                STA     _fcc_fpr0
                LDA     11,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _struct_ret_L14-1
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
_struct_ret_L14
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #6
                BNE     _struct_ret_L13
                LDA     #8
                PHA
                LDA     #7
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #46
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     19,S   ; fccstk d=8 b=11
                STA     _fcc_fpr0+2
                LDA     17,S   ; fccstk d=8 b=9
                STA     _fcc_fpr0
                PHK
                PEA     _struct_ret_L15-1
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
_struct_ret_L15
                PLY
                PLY
                PLY
                PLY
                LDA     [_fcc_fpr0]
                TAX
                CMP     #7
                BEQ     _struct_ret_L12
_struct_ret_L13
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
_struct_ret_L12
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
                ADC     #54
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum
                PLY
                PLY
                PLY
                LDA     [_fcc_fpr0]
                TAX
                CMP     #10
                BEQ     _struct_ret_L16
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
_struct_ret_L16
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #14
                PHA
                LDA     #13
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #62
                STA     _fcc_fpr1
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDY     #6
_struct_ret_L17
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_ret_L17
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #70
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL viap
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #14
                BNE     _struct_ret_L19
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #8
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #6
_struct_ret_L20
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_ret_L20
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #78
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL viacast
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     [_fcc_fpr0]
                TAX
                CMP     #13
                BEQ     _struct_ret_L18
_struct_ret_L19
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
_struct_ret_L18
                LDA     #12
                PHA
                LDA     #30
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #86
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
                LDA     [_fcc_fpr0]
                PHA
                LDA     #12
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #94
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
                LDA     #9
                PHA
                LDA     #9
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #102
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL mk
                PLY
                PLY
                PLY
                PLY
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
main_FRAMESIZE   EQU     110
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 18
