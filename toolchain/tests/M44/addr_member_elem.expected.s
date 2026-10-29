                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from addr_member_elem.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fill
fill            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fill_FRAMESIZE
                DO      fill_STKGUARD
                BCC     fill_stkovf
                CMP     _fcc_stkfloor
                BCS     fill_stkok
fill_stkovf       JMP     _fcc_stkoflow
                FIN
fill_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     21,S   ; fccstk d=0 b=21
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     two+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     two
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #26
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #16388
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #50
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #9
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                ADC     #62
                CLC
                ADC     #6
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     #12
                STA     [_fcc_fpr0]
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     two+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     two
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addr_member_elem_L2
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addr_member_elem_L2
                LDA     #0
                BRA     _addr_member_elem_L3
_addr_member_elem_L2
                LDA     #1
_addr_member_elem_L3
                CMP     #0
                BEQ     *+5
                BRL     _addr_member_elem_L1
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addr_member_elem_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addr_member_elem_L4
                LDA     #0
                BRA     _addr_member_elem_L5
_addr_member_elem_L4
                LDA     #1
_addr_member_elem_L5
                CMP     #0
                BNE     _addr_member_elem_L1
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                INC
                INC
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addr_member_elem_L6
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addr_member_elem_L6
                LDA     #0
                BRA     _addr_member_elem_L7
_addr_member_elem_L6
                LDA     #1
_addr_member_elem_L7
                CMP     #0
                BEQ     _addr_member_elem_L0
_addr_member_elem_L1
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     #1
                STA     21,S   ; fccstk d=0 b=21
_addr_member_elem_L0
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #4464
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _addr_member_elem_L9
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #1
                ASL
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
                BEQ     _addr_member_elem_L8
_addr_member_elem_L9
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     #1
                STA     21,S   ; fccstk d=0 b=21
_addr_member_elem_L8
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                ADC     #26
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16388
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BEQ     *+5
                BRL     _addr_member_elem_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                ADC     #26
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BEQ     _addr_member_elem_L10
_addr_member_elem_L11
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     #1
                STA     21,S   ; fccstk d=0 b=21
_addr_member_elem_L10
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #50
                STA     _fcc_fpr0
                LDA     #2
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                CMP     #9
                BNE     _addr_member_elem_L13
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fill_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #50
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                BEQ     _addr_member_elem_L12
_addr_member_elem_L13
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     #1
                STA     21,S   ; fccstk d=0 b=21
_addr_member_elem_L12
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                ADC     #62
                CLC
                ADC     #6
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #12
                BNE     _addr_member_elem_L15
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+fill_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
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
                ADC     #62
                CLC
                ADC     #6
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _addr_member_elem_L14
_addr_member_elem_L15
                LDA     21,S   ; fccstk d=0 b=21
                CLC
                ADC     #1
                STA     21,S   ; fccstk d=0 b=21
_addr_member_elem_L14
                LDA     21,S   ; fccstk d=0 b=21
                TAY
                TSC
                CLC
                ADC     #fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fill_FRAMESIZE   EQU     22
fill_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                TSC
                SEC
                SBC     #main_FRAMESIZE-2
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
                STA     25,S   ; fccstk d=0 b=25
                LDA     #2
                ASL
                ASL
                CLC
                ADC     #c+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     one+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     one
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #c+14
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #2
                ASL
                ASL
                ASL
                CLC
                ADC     #c+26
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
                LDA     #16352
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #c+50
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     19,S   ; fccstk d=0 b=19
                LDA     _fcc_fpr0
                STA     17,S   ; fccstk d=0 b=17
                LDA     #5
                STA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c+64
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     23,S   ; fccstk d=0 b=23
                LDA     _fcc_fpr0
                STA     21,S   ; fccstk d=0 b=21
                LDA     #7
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     c+12
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     c+10
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     one+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     one
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addr_member_elem_L18
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addr_member_elem_L18
                LDA     #0
                BRA     _addr_member_elem_L19
_addr_member_elem_L18
                LDA     #1
_addr_member_elem_L19
                CMP     #0
                BNE     _addr_member_elem_L17
                SEP     #$20
                MX      %10
                LDA     c+8
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     c+6
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addr_member_elem_L20
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addr_member_elem_L20
                LDA     #0
                BRA     _addr_member_elem_L21
_addr_member_elem_L20
                LDA     #1
_addr_member_elem_L21
                CMP     #0
                BEQ     _addr_member_elem_L16
_addr_member_elem_L17
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_addr_member_elem_L16
                LDA     c+20
                STA     _fcc_long_hi
                LDA     c+18
                LDX     #57920
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BNE     _addr_member_elem_L23
                LDA     c+24
                STA     _fcc_long_hi
                LDA     c+22
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _addr_member_elem_L22
_addr_member_elem_L23
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_addr_member_elem_L22
                LDA     c+48
                STA     _fcc_q3
                LDA     c+46
                STA     _fcc_q2
                LDA     c+44
                STA     _fcc_long_hi
                LDA     c+42
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #16352
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                CMP     #0
                BNE     _addr_member_elem_L25
                LDA     c+40
                STA     _fcc_q3
                LDA     c+38
                STA     _fcc_q2
                LDA     c+36
                STA     _fcc_long_hi
                LDA     c+34
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                LDX     _fcc_q2
                STX     _fcc_qb2
                LDX     _fcc_q3
                STX     _fcc_qb3
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                PLA
                STA     _fcc_q2
                PLA
                STA     _fcc_q3
                TYA
                FGX2_FARCALL _fcc_dcmp
                BNE     *+7
                LDA     #0
                BRA     *+5
                LDA     #1
                BEQ     _addr_member_elem_L24
_addr_member_elem_L25
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_addr_member_elem_L24
                LDA     c+54
                CMP     #5
                BNE     _addr_member_elem_L27
                LDA     c+50
                BEQ     _addr_member_elem_L26
_addr_member_elem_L27
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_addr_member_elem_L26
                LDA     c+64
                CMP     #7
                BNE     _addr_member_elem_L29
                LDA     c+66
                BNE     _addr_member_elem_L29
                LDA     c+68
                BEQ     _addr_member_elem_L28
_addr_member_elem_L29
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_addr_member_elem_L28
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #c+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                TYA
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #c+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _addr_member_elem_L30
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_addr_member_elem_L30
                LDA     #0
                STA     _fcc_img16
_addr_member_elem_L31
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #3
                BVC     _addr_member_elem_L34
                EOR     #$8000
_addr_member_elem_L34
                BMI     *+5
                BRL     _addr_member_elem_L33
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_img16
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_fpr1+2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     _fcc_img16
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                JSR     _fcc_long_from_int
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #26
                STA     _fcc_fpr0
                LDA     _fcc_img16
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #50
                STA     _fcc_fpr0
                LDA     _fcc_img16
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #50
                STA     _fcc_fpr0
                LDA     _fcc_img16
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
_addr_member_elem_L32
                INC     _fcc_img16
                BRL     _addr_member_elem_L31
_addr_member_elem_L33
                LDA     #0
                STA     _fcc_img16
_addr_member_elem_L35
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #3
                BVC     _addr_member_elem_L38
                EOR     #$8000
_addr_member_elem_L38
                BPL     _addr_member_elem_L37
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #62
                STA     _fcc_fpr0
                LDA     _fcc_img16
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #62
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     _fcc_img16
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                STA     [_fcc_fpr0]
_addr_member_elem_L36
                INC     _fcc_img16
                BRA     _addr_member_elem_L35
_addr_member_elem_L37
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                INC
                INC
                STA     _fcc_fpr0
                LDA     #1
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     two+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     two
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #62
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     23,S   ; fccstk d=0 b=23
                LDA     _fcc_fpr0
                STA     21,S   ; fccstk d=0 b=21
                LDA     #4
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                INC
                INC
                CLC
                ADC     #4
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
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     two+2
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     two
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addr_member_elem_L41
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addr_member_elem_L41
                LDA     #0
                BRA     _addr_member_elem_L42
_addr_member_elem_L41
                LDA     #1
_addr_member_elem_L42
                CMP     #0
                BEQ     *+5
                BRL     _addr_member_elem_L40
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                INC
                INC
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
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _addr_member_elem_L43
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _addr_member_elem_L43
                LDA     #0
                BRA     _addr_member_elem_L44
_addr_member_elem_L43
                LDA     #1
_addr_member_elem_L44
                CMP     #0
                BNE     _addr_member_elem_L40
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #62
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #4
                BNE     _addr_member_elem_L40
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #28
                CLC
                ADC     #62
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _addr_member_elem_L39
_addr_member_elem_L40
                LDA     25,S   ; fccstk d=0 b=25
                CLC
                ADC     #1
                STA     25,S   ; fccstk d=0 b=25
_addr_member_elem_L39
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c+10
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #c+14
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                JSR     _fcc_long_from_int
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #0
                STA     _fcc_q3
                LDA     #0
                STA     _fcc_q2
                LDA     #0
                STA     _fcc_long_hi
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c+42
                STA     _fcc_fpr0
                PLA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #c+50
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                STA     [_fcc_fpr0]
                LDA     #0
                STA     c+64
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #c
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     cp
                LDA     _fcc_fpr0+2
                STA     cp+2
                LDA     25,S   ; fccstk d=0 b=25
                PHA
                SEP     #$20
                MX      %10
                LDA     cp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     cp
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fill
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     25,S   ; fccstk d=0 b=25
                BEQ     _addr_member_elem_L45
                LDA     25,S   ; fccstk d=0 b=25
                BRA     _addr_member_elem_L46
_addr_member_elem_L45
                LDA     #42
_addr_member_elem_L46
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-2
                TCS
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     104
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
