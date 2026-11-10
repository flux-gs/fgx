                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_arg_deref.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _struct_arg_deref_viaparam
_struct_arg_deref_viaparam            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_struct_arg_deref_viaparam_FRAMESIZE
                DO      _struct_arg_deref_viaparam_STKGUARD
                BCC     _struct_arg_deref_viaparam_stkovf
                CMP     _fcc_stkfloor
                BCS     _struct_arg_deref_viaparam_stkok
_struct_arg_deref_viaparam_stkovf       JMP     _fcc_stkoflow
                FIN
_struct_arg_deref_viaparam_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_struct_arg_deref_viaparam_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_struct_arg_deref_viaparam_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_struct_arg_deref_viaparam_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_struct_arg_deref_viaparam_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_struct_arg_deref_viaparam_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_struct_arg_deref_viaparam_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_deref_L0
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_deref_L0
                FGX2_FARCALL netof
                PLY
                PLY
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                TAY
                TSC
                CLC
                ADC     #_struct_arg_deref_viaparam_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_struct_arg_deref_viaparam_FRAMESIZE   EQU     0
_struct_arg_deref_viaparam_STKGUARD    EQU     0
                FGX2_EXPORT _struct_arg_deref_viareg
_struct_arg_deref_viareg            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_struct_arg_deref_viareg_FRAMESIZE
                DO      _struct_arg_deref_viareg_STKGUARD
                BCC     _struct_arg_deref_viareg_stkovf
                CMP     _fcc_stkfloor
                BCS     _struct_arg_deref_viareg_stkok
_struct_arg_deref_viareg_stkovf       JMP     _fcc_stkoflow
                FIN
_struct_arg_deref_viareg_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_struct_arg_deref_viareg_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_struct_arg_deref_viareg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_struct_arg_deref_viareg_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_struct_arg_deref_viareg_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_struct_arg_deref_viareg_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_struct_arg_deref_viareg_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_deref_L1
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_deref_L1
                FGX2_FARCALL netof
                PLY
                PLY
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                TAY
                TSC
                CLC
                ADC     #_struct_arg_deref_viareg_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_struct_arg_deref_viareg_FRAMESIZE   EQU     0
_struct_arg_deref_viareg_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     23,S   ; fccstk d=0 b=23
                LDA     #$0403
                STA     _fcc_long_hi
                LDA     #$0201
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     #$0201
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
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
_struct_arg_deref_L2
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_arg_deref_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                LDA     #1
                STA     13,S   ; fccstk d=0 b=13
                LDA     #2
                STA     15,S   ; fccstk d=0 b=15
                LDA     #3
                STA     17,S   ; fccstk d=0 b=17
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
                FGX2_FARCALL _struct_arg_deref_viaparam
                PLY
                PLY
                CMP     #0
                BNE     _struct_arg_deref_L3
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                ORA     #1
                STA     23,S   ; fccstk d=0 b=23
_struct_arg_deref_L3
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
                FGX2_FARCALL _struct_arg_deref_viareg
                PLY
                PLY
                CMP     #0
                BNE     _struct_arg_deref_L4
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                ORA     #2
                STA     23,S   ; fccstk d=0 b=23
_struct_arg_deref_L4
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_deref_L6
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_deref_L6
                FGX2_FARCALL netof
                PLY
                PLY
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_deref_L5
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                ORA     #4
                STA     23,S   ; fccstk d=0 b=23
_struct_arg_deref_L5
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
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_deref_L8
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_deref_L8
                FGX2_FARCALL netof
                PLY
                PLY
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_deref_L7
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                ORA     #8
                STA     23,S   ; fccstk d=0 b=23
_struct_arg_deref_L7
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_struct_arg_deref_L10
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_deref_L10
                FGX2_FARCALL sum6
                PLY
                PLY
                PLY
                TAX
                CMP     #6
                BEQ     _struct_arg_deref_L9
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                ORA     #16
                STA     23,S   ; fccstk d=0 b=23
_struct_arg_deref_L9
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_deref_L12
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_deref_L12
                FGX2_FARCALL proto
                PLY
                PLY
                CMP     #513
                BEQ     _struct_arg_deref_L11
                LDA     23,S   ; fccstk d=0 b=23
                ORA     #32
                STA     23,S   ; fccstk d=0 b=23
_struct_arg_deref_L11
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                LDX     #513
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_deref_L13
                LDA     23,S   ; fccstk d=0 b=23
                TAX
                ORA     #64
                STA     23,S   ; fccstk d=0 b=23
_struct_arg_deref_L13
                LDA     23,S   ; fccstk d=0 b=23
                BEQ     _struct_arg_deref_L14
                LDA     23,S   ; fccstk d=0 b=23
                BRA     _struct_arg_deref_L15
_struct_arg_deref_L14
                LDA     #42
_struct_arg_deref_L15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     28
main_STKGUARD    EQU     0
                FGX2_EXPORT netof
netof            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #netof_FRAMESIZE
                DO      netof_STKGUARD
                BCC     netof_stkovf
                CMP     _fcc_stkfloor
                BCS     netof_stkok
netof_stkovf       JMP     _fcc_stkoflow
                FIN
netof_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+netof_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+netof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+netof_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+netof_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+netof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+netof_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFF
                STA     _fcc_long_hi
                LDA     #$FF00
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_and
                STA     _fcc_tmp_b
                DO      6+netof_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+netof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+netof_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_long_hi
                DO      8+netof_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #10+netof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     8+netof_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                LDA     _fcc_tmp_b
                DO      8+netof_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+netof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+netof_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+netof_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+netof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+netof_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #netof_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
netof_FRAMESIZE   EQU     0
netof_STKGUARD    EQU     0
                FGX2_EXPORT sum6
sum6            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sum6_FRAMESIZE
                DO      sum6_STKGUARD
                BCC     sum6_stkovf
                CMP     _fcc_stkfloor
                BCS     sum6_stkok
sum6_stkovf       JMP     _fcc_stkoflow
                FIN
sum6_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+sum6_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum6_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum6_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      10+sum6_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sum6_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sum6_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      12+sum6_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sum6_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sum6_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sum6_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum6_FRAMESIZE   EQU     0
sum6_STKGUARD    EQU     0
                FGX2_EXPORT proto
proto            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #proto_FRAMESIZE
                DO      proto_STKGUARD
                BCC     proto_stkovf
                CMP     _fcc_stkfloor
                BCS     proto_stkok
proto_stkovf       JMP     _fcc_stkoflow
                FIN
proto_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+proto_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+proto_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+proto_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+proto_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+proto_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+proto_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                TAY
                TSC
                CLC
                ADC     #proto_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
proto_FRAMESIZE   EQU     0
proto_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 15
