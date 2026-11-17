                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_elem_assign.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _struct_elem_assign_padof
_struct_elem_assign_padof            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_struct_elem_assign_padof_FRAMESIZE
                DO      _struct_elem_assign_padof_STKGUARD
                BCC     _struct_elem_assign_padof_stkovf
                CMP     _fcc_stkfloor
                BCS     _struct_elem_assign_padof_stkok
_struct_elem_assign_padof_stkovf       JMP     _fcc_stkoflow
                FIN
_struct_elem_assign_padof_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_struct_elem_assign_padof_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_struct_elem_assign_padof_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_struct_elem_assign_padof_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_struct_elem_assign_padof_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_struct_elem_assign_padof_FRAMESIZE   EQU     0
_struct_elem_assign_padof_STKGUARD    EQU     0
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
                LDA     #1
                STA     7,S   ; fccstk d=0 b=7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ip_srcrt
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     #7
                STA     5,S   ; fccstk d=0 b=5
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
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr1
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     #0
                JSR     _fcc_long_from_int
                STA     [_fcc_fpr1]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr1],Y
                TXA
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #0
                JSR     _fcc_long_from_int
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr2+2
                REP     #$20
                MX      %00
                LDA     #ip_srcrt+20
                STA     _fcc_fpr2
                PLA
                STA     [_fcc_fpr2]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr2],Y
                TXA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #ip_srcrt+14
                STA     _fcc_fpr1
                PLA
                STA     [_fcc_fpr1]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr1],Y
                TXA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ip_srcrt+2
                STA     _fcc_fpr0
                PLA
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     #ip_srcrt+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
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
                LDY     #4
_struct_elem_assign_L0
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_elem_assign_L0
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
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
                LDY     #4
_struct_elem_assign_L1
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_elem_assign_L1
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                INC
                INC
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                INC
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                STA     _fcc_fpr1
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDY     #4
_struct_elem_assign_L2
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _struct_elem_assign_L2
                LDA     ip_srcrt+10
                STA     _fcc_long_hi
                LDA     ip_srcrt+8
                LDX     #22136
                STX     _fcc_long_b_lo
                LDX     #4660
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _struct_elem_assign_L4
                LDA     ip_srcrt+12
                TAX
                CMP     #7
                BEQ     _struct_elem_assign_L3
_struct_elem_assign_L4
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_struct_elem_assign_L3
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
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #22136
                STX     _fcc_long_b_lo
                LDX     #4660
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _struct_elem_assign_L6
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
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _struct_elem_assign_L6
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
                LDA     #2
                ASL
                INC
                INC
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_elem_assign_L5
_struct_elem_assign_L6
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_struct_elem_assign_L5
                LDA     ip_srcrt+16
                STA     _fcc_long_hi
                LDA     ip_srcrt+14
                LDX     #22136
                STX     _fcc_long_b_lo
                LDX     #4660
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _struct_elem_assign_L8
                LDA     ip_srcrt+18
                TAX
                CMP     #7
                BEQ     _struct_elem_assign_L7
_struct_elem_assign_L8
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_struct_elem_assign_L7
                LDA     ip_srcrt+4
                STA     _fcc_long_hi
                LDA     ip_srcrt+2
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _struct_elem_assign_L10
                LDA     ip_srcrt+22
                STA     _fcc_long_hi
                LDA     ip_srcrt+20
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _struct_elem_assign_L9
_struct_elem_assign_L10
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_struct_elem_assign_L9
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
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
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
_struct_elem_assign_L13
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_elem_assign_L13
                FGX2_FARCALL _struct_elem_assign_padof
                PLY
                PLY
                PLY
                TAX
                CMP     #7
                BNE     _struct_elem_assign_L12
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                INC
                INC
                STA     _fcc_fpr0
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                INC
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
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
_struct_elem_assign_L14
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _struct_elem_assign_L14
                FGX2_FARCALL _struct_elem_assign_padof
                PLY
                PLY
                PLY
                TAX
                CMP     #7
                BEQ     _struct_elem_assign_L11
_struct_elem_assign_L12
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_struct_elem_assign_L11
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
main_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     34
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 5
