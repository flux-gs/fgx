                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_arg_member.c
;---------------------------------------

                MX      %00
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+sum_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_FRAMESIZE   EQU     4
sum_STKGUARD    EQU     0
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #$0403
                STA     _fcc_long_hi
                LDA     #$0201
                STA     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                CLC
                ADC     #4
                CLC
                ADC     #6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
_struct_arg_member_L0
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_arg_member_L0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                INC
                INC
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #2
_struct_arg_member_L1
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_arg_member_L1
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
_struct_arg_member_L3
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_member_L3
                FGX2_FARCALL sum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _struct_arg_member_L2
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_struct_arg_member_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                CLC
                ADC     #4
                CLC
                ADC     #6
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
_struct_arg_member_L5
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_member_L5
                FGX2_FARCALL sum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _struct_arg_member_L4
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_struct_arg_member_L4
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
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #10
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
_struct_arg_member_L7
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_member_L7
                FGX2_FARCALL sum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _struct_arg_member_L6
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #4
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_struct_arg_member_L6
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
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                INC
                INC
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
_struct_arg_member_L9
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_arg_member_L9
                FGX2_FARCALL sum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _struct_arg_member_L8
                LDA     9,S   ; fccstk d=0 b=9
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                ORA     _fcc_tmp_b
                STA     9,S   ; fccstk d=0 b=9
_struct_arg_member_L8
                LDA     9,S   ; fccstk d=0 b=9
                CMP     #0
                BNE     *+5
                BRL     _struct_arg_member_L10
                LDA     9,S   ; fccstk d=0 b=9
                BRL     _struct_arg_member_L11
_struct_arg_member_L10
                LDA     #42
_struct_arg_member_L11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     24
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
