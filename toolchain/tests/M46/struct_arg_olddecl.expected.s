                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_arg_olddecl.c
;---------------------------------------

                MX      %00
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
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     27,S   ; fccstk d=0 b=27
                LDA     #$0403
                STA     _fcc_long_hi
                LDA     #$0201
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_long_hi
                STA     15,S   ; fccstk d=0 b=15
                LDA     #$0201
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
_struct_arg_olddecl_L0
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L0
                LDA     #1
                STA     17,S   ; fccstk d=0 b=17
                LDA     #2
                STA     19,S   ; fccstk d=0 b=19
                LDA     #3
                STA     21,S   ; fccstk d=0 b=21
                SEP     #$20
                MX      %10
                LDA     _struct_arg_olddecl_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _struct_arg_olddecl_FA1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     25,S   ; fccstk d=0 b=25
                LDA     _fcc_fpr0
                STA     23,S   ; fccstk d=0 b=23
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_olddecl_L3
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L3
                FGX2_FARCALL netof
                PLY
                PLY
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_olddecl_L2
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                ORA     #1
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                CLC
                ADC     #4
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
_struct_arg_olddecl_L5
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L5
                FGX2_FARCALL netof
                PLY
                PLY
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_olddecl_L4
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                ORA     #2
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L4
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #4
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
_struct_arg_olddecl_L7
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L7
                FGX2_FARCALL netof
                PLY
                PLY
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_olddecl_L6
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                ORA     #4
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L6
                LDA     25,S   ; fccstk d=0 b=25
                STA     _fcc_fpr0+2
                LDA     23,S   ; fccstk d=0 b=23
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #4
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
_struct_arg_olddecl_L9
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L9
                LDA     5,S
                STA     _fcc_fpr0
                LDA     7,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _struct_arg_olddecl_L10-1
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
_struct_arg_olddecl_L10
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDX     #512
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_olddecl_L8
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                ORA     #8
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L8
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #16
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #6
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #4
_struct_arg_olddecl_L12
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L12
                FGX2_FARCALL sum6
                PLY
                PLY
                PLY
                TAX
                CMP     #6
                BEQ     _struct_arg_olddecl_L11
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                ORA     #16
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L11
                LDA     #9
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_olddecl_L14
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L14
                LDA     #7
                PHA
                FGX2_FARCALL mid
                PLY
                PLY
                PLY
                PLY
                PHA
                LDA     #7
                INC
                TAX
                CLC
                ADC     #9
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _struct_arg_olddecl_L13
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                ORA     #32
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L13
                LDA     #5
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_struct_arg_olddecl_L16
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L16
                LDA     #1
                PHA
                FGX2_FARCALL vsum
                PLY
                PLY
                PLY
                PLY
                PHA
                LDA     #1
                INC
                CLC
                ADC     #5
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _struct_arg_olddecl_L15
                LDA     27,S   ; fccstk d=0 b=27
                ORA     #128
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L15
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_long_hi
                STA     15,S   ; fccstk d=0 b=15
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                LDX     #513
                STX     _fcc_long_b_lo
                LDX     #1027
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_arg_olddecl_L17
                LDA     27,S   ; fccstk d=0 b=27
                TAX
                ORA     #64
                STA     27,S   ; fccstk d=0 b=27
_struct_arg_olddecl_L17
                LDA     27,S   ; fccstk d=0 b=27
                BEQ     _struct_arg_olddecl_L18
                LDA     27,S   ; fccstk d=0 b=27
                BRA     _struct_arg_olddecl_L19
_struct_arg_olddecl_L18
                LDA     #42
_struct_arg_olddecl_L19
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
main_FRAMESIZE   EQU     32
main_STKGUARD    EQU     1
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
                FGX2_EXPORT mid
mid            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #mid_FRAMESIZE
                DO      mid_STKGUARD
                BCC     mid_stkovf
                CMP     _fcc_stkfloor
                BCS     mid_stkok
mid_stkovf       JMP     _fcc_stkoflow
                FIN
mid_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+mid_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+mid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+mid_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+mid_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+mid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+mid_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_long_hi
                DO      10+mid_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+mid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+mid_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                LDX     #255
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      14+mid_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+mid_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+mid_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #mid_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mid_FRAMESIZE   EQU     0
mid_STKGUARD    EQU     0
                FGX2_EXPORT vsum
vsum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vsum_FRAMESIZE
                DO      vsum_STKGUARD
                BCC     vsum_stkovf
                CMP     _fcc_stkfloor
                BCS     vsum_stkok
vsum_stkovf       JMP     _fcc_stkoflow
                FIN
vsum_stkok        TCS
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
                ADC     #6+vsum_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #2
                TAX
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr1+2
                LDA     _fcc_img0
                STA     _fcc_fpr1
                LDA     #4
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr1+2
                STA     _fcc_img1
                LDA     _fcc_fpr1
                STA     _fcc_img0
                LDA     #4
                TAX
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     _fcc_tmp_b
                LDA     _fcc_fpr1
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr1
                LDY     #2
_struct_arg_olddecl_L20
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_arg_olddecl_L20
                DO      6+vsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_long_hi
                LDA     7,S   ; fccstk d=2 b=5
                LDX     #255
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_and
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     _fcc_img1
                STA     _fcc_fpr0+2
                LDA     _fcc_img0
                STA     _fcc_fpr0
                LDA     #2
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #2
                TAX
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                TSC
                CLC
                ADC     #vsum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vsum_FRAMESIZE   EQU     10
vsum_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 12
