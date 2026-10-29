                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from p33_soft_addr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT psum
psum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #psum_FRAMESIZE
                DO      psum_STKGUARD
                BCC     psum_stkovf
                CMP     _fcc_stkfloor
                BCS     psum_stkok
psum_stkovf       JMP     _fcc_stkoflow
                FIN
psum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+psum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+psum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+psum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+psum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+psum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+psum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      10+psum_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+psum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+psum_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+psum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+psum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+psum_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #psum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
psum_FRAMESIZE   EQU     0
psum_STKGUARD    EQU     0
                FGX2_EXPORT addr_of
addr_of            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #addr_of_FRAMESIZE
                DO      addr_of_STKGUARD
                BCC     addr_of_stkovf
                CMP     _fcc_stkfloor
                BCS     addr_of_stkok
addr_of_stkovf       JMP     _fcc_stkoflow
                FIN
addr_of_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _fcc_sfp
                SEC
                SBC     #addr_of_SOFTSIZE
                BCC     addr_of_sfovf
                CMP     #$0100
                BCS     addr_of_sfok
addr_of_sfovf        JMP     _fcc_sfoflow
addr_of_sfok         STA     _fcc_sfp
                DO      6+addr_of_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+addr_of_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+addr_of_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDY     #0
                STA     [_fcc_sfp],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                LDY     #4
                STA     [_fcc_sfp],Y
                LDA     _fcc_fpr0
                LDY     #2
                STA     [_fcc_sfp],Y
                DO      6+addr_of_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+addr_of_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+addr_of_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _p33_soft_addr_L1
                EOR     #$8000
_p33_soft_addr_L1
                BMI     *+5
                BRL     _p33_soft_addr_L0
                LDY     #4
                LDA     [_fcc_sfp],Y
                STA     _fcc_fpr0+2
                LDY     #2
                LDA     [_fcc_sfp],Y
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_sfp],Y
                STA     _fcc_ptr
                LDY     #4
                LDA     [_fcc_sfp],Y
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                DO      12+addr_of_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+addr_of_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+addr_of_FRAMESIZE,S   ; fccstk d=6 b=6 fs
                FIN
                TAX
                TXA
                DEC
                PHA
                FGX2_FARCALL addr_of
                TAY
                PLA
                TYA
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     [_fcc_fpr0]
_p33_soft_addr_L0
                LDY     #2
                LDA     [_fcc_sfp],Y
                STA     _fcc_ptr
                LDY     #4
                LDA     [_fcc_sfp],Y
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_sfp
                CLC
                ADC     #addr_of_SOFTSIZE
                STA     _fcc_sfp
                TSC
                CLC
                ADC     #addr_of_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
addr_of_FRAMESIZE   EQU     0
addr_of_SOFTSIZE    EQU     6
addr_of_STKGUARD    EQU     1
                FGX2_EXPORT elems
elems            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #elems_FRAMESIZE
                DO      elems_STKGUARD
                BCC     elems_stkovf
                CMP     _fcc_stkfloor
                BCS     elems_stkok
elems_stkovf       JMP     _fcc_stkoflow
                FIN
elems_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _fcc_sfp
                SEC
                SBC     #elems_SOFTSIZE
                BCC     elems_sfovf
                CMP     #$0100
                BCS     elems_sfok
elems_sfovf        JMP     _fcc_sfoflow
elems_sfok         STA     _fcc_sfp
                LDA     #0
                LDY     #12
                STA     [_fcc_sfp],Y
                LDY     #12
                LDA     [_fcc_sfp],Y
                STA     _fcc_img0
                DO      6+elems_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+elems_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+elems_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
_p33_soft_addr_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #4
                BVC     _p33_soft_addr_L5
                EOR     #$8000
_p33_soft_addr_L5
                BMI     *+5
                BRL     _p33_soft_addr_L4
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #0
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img1
                CLC
                ADC     _fcc_img0
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
_p33_soft_addr_L3
                INC     _fcc_img0
                BRL     _p33_soft_addr_L2
_p33_soft_addr_L4
                LDA     _fcc_img0
                LDY     #12
                STA     [_fcc_sfp],Y
                LDA     _fcc_img1
                DO      6+elems_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+elems_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+elems_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #4
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #0
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                JSR     _fcc_long_from_int
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     _fcc_long_hi
                STA     [_fcc_ptr]
                PLA
                LDA     _fcc_sfp
                CLC
                ADC     #4
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_sfp
                CLC
                ADC     #4
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                CLC
                ADC     #2
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                JSR     _fcc_long_from_int
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
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     _fcc_long_hi
                STA     [_fcc_ptr]
                PLA
                DO      6+elems_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+elems_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+elems_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _p33_soft_addr_L7
                EOR     #$8000
_p33_soft_addr_L7
                BMI     *+5
                BRL     _p33_soft_addr_L6
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #4
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      10+elems_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+elems_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+elems_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                TAX
                TXA
                SEC
                SBC     #1
                PHA
                FGX2_FARCALL elems
                TAY
                PLA
                TYA
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
                LDA     _fcc_sfp
                CLC
                ADC     #elems_SOFTSIZE
                STA     _fcc_sfp
                TSC
                CLC
                ADC     #elems_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_soft_addr_L6
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #4
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_sfp
                CLC
                ADC     #elems_SOFTSIZE
                STA     _fcc_sfp
                TSC
                CLC
                ADC     #elems_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
elems_FRAMESIZE   EQU     0
elems_SOFTSIZE    EQU     14
elems_STKGUARD    EQU     1
                FGX2_EXPORT rowsum
rowsum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #rowsum_FRAMESIZE
                DO      rowsum_STKGUARD
                BCC     rowsum_stkovf
                CMP     _fcc_stkfloor
                BCS     rowsum_stkok
rowsum_stkovf       JMP     _fcc_stkoflow
                FIN
rowsum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _fcc_sfp
                SEC
                SBC     #rowsum_SOFTSIZE
                BCC     rowsum_sfovf
                CMP     #$0100
                BCS     rowsum_sfok
rowsum_sfovf        JMP     _fcc_sfoflow
rowsum_sfok         STA     _fcc_sfp
                LDA     #0
                LDY     #4
                STA     [_fcc_sfp],Y
                LDY     #4
                LDA     [_fcc_sfp],Y
                STA     _fcc_img0
                DO      6+rowsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+rowsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+rowsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
_p33_soft_addr_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _p33_soft_addr_L11
                EOR     #$8000
_p33_soft_addr_L11
                BMI     *+5
                BRL     _p33_soft_addr_L10
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #8
                PHA
                LDA     #0
                ASL
                CLC
                ADC     #0
                ASL
                PHA
                LDA     _fcc_img0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
                LDA     _fcc_sfp
                CLC
                ADC     #8
                PHA
                LDA     #1
                ASL
                INC
                ASL
                PHA
                LDA     _fcc_img0
                ASL
                CLC
                ADC     1,S
                STA     1,S
                PLA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                CLC
                ADC     _fcc_img1
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
_p33_soft_addr_L9
                INC     _fcc_img0
                BRL     _p33_soft_addr_L8
_p33_soft_addr_L10
                LDA     _fcc_img0
                LDY     #4
                STA     [_fcc_sfp],Y
                LDA     _fcc_img1
                DO      6+rowsum_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+rowsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+rowsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #8
                PHA
                LDA     #1
                ASL
                INC
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                LDY     #2
                STA     [_fcc_sfp],Y
                LDA     _fcc_fpr0
                LDY     #0
                STA     [_fcc_sfp],Y
                LDY     #2
                LDA     [_fcc_sfp],Y
                STA     _fcc_ptr+2
                LDY     #0
                LDA     [_fcc_sfp],Y
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                PHA
                LDY     #2
                LDA     [_fcc_sfp],Y
                STA     _fcc_ptr+2
                LDY     #0
                LDA     [_fcc_sfp],Y
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDY     #2
                LDA     [_fcc_sfp],Y
                STA     _fcc_ptr+2
                LDY     #0
                LDA     [_fcc_sfp],Y
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                LDY     #6
                STA     [_fcc_sfp],Y
                DO      6+rowsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+rowsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+rowsum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _p33_soft_addr_L13
                EOR     #$8000
_p33_soft_addr_L13
                BMI     *+5
                BRL     _p33_soft_addr_L12
                LDY     #6
                LDA     [_fcc_sfp],Y
                PHA
                DO      8+rowsum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+rowsum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+rowsum_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                TAX
                TXA
                DEC
                PHA
                FGX2_FARCALL rowsum
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                LDY     #6
                STA     [_fcc_sfp],Y
_p33_soft_addr_L12
                LDY     #6
                LDA     [_fcc_sfp],Y
                TAY
                LDA     _fcc_sfp
                CLC
                ADC     #rowsum_SOFTSIZE
                STA     _fcc_sfp
                TSC
                CLC
                ADC     #rowsum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
rowsum_FRAMESIZE   EQU     0
rowsum_SOFTSIZE    EQU     20
rowsum_STKGUARD    EQU     1
                FGX2_EXPORT crosspath
crosspath            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #crosspath_FRAMESIZE
                DO      crosspath_STKGUARD
                BCC     crosspath_stkovf
                CMP     _fcc_stkfloor
                BCS     crosspath_stkok
crosspath_stkovf       JMP     _fcc_stkoflow
                FIN
crosspath_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     _fcc_sfp
                SEC
                SBC     #crosspath_SOFTSIZE
                BCC     crosspath_sfovf
                CMP     #$0100
                BCS     crosspath_sfok
crosspath_sfovf        JMP     _fcc_sfoflow
crosspath_sfok         STA     _fcc_sfp
                DO      6+crosspath_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+crosspath_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+crosspath_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDY     #0
                STA     [_fcc_sfp],Y
                DO      6+crosspath_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+crosspath_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+crosspath_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                INC
                LDY     #2
                STA     [_fcc_sfp],Y
                LDY     #0
                LDA     [_fcc_sfp],Y
                PHA
                LDY     #2
                LDA     [_fcc_sfp],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                LDY     #4
                STA     [_fcc_sfp],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_sfp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_sfp
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL psum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDY     #6
                STA     [_fcc_sfp],Y
                LDY     #4
                LDA     [_fcc_sfp],Y
                PHA
                LDY     #6
                LDA     [_fcc_sfp],Y
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _p33_soft_addr_L14
                LDA     #$FFFF
                TAY
                LDA     _fcc_sfp
                CLC
                ADC     #crosspath_SOFTSIZE
                STA     _fcc_sfp
                TSC
                CLC
                ADC     #crosspath_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_soft_addr_L14
                DO      6+crosspath_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+crosspath_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+crosspath_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _p33_soft_addr_L16
                EOR     #$8000
_p33_soft_addr_L16
                BMI     *+5
                BRL     _p33_soft_addr_L15
                DO      6+crosspath_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+crosspath_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+crosspath_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                TXA
                DEC
                PHA
                FGX2_FARCALL crosspath
                TAY
                PLA
                TYA
                LDY     #6
                STA     [_fcc_sfp],Y
                LDY     #6
                LDA     [_fcc_sfp],Y
                TAX
                TXA
                SEC
                SBC     #0
                BVC     _p33_soft_addr_L18
                EOR     #$8000
_p33_soft_addr_L18
                BMI     *+5
                BRL     _p33_soft_addr_L17
                LDA     #$FFFF
                TAY
                LDA     _fcc_sfp
                CLC
                ADC     #crosspath_SOFTSIZE
                STA     _fcc_sfp
                TSC
                CLC
                ADC     #crosspath_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_p33_soft_addr_L17
                LDY     #4
                LDA     [_fcc_sfp],Y
                LDY     #6
                CLC
                ADC     [_fcc_sfp],Y
                LDY     #4
                STA     [_fcc_sfp],Y
_p33_soft_addr_L15
                LDY     #4
                LDA     [_fcc_sfp],Y
                TAY
                LDA     _fcc_sfp
                CLC
                ADC     #crosspath_SOFTSIZE
                STA     _fcc_sfp
                TSC
                CLC
                ADC     #crosspath_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
crosspath_FRAMESIZE   EQU     0
crosspath_SOFTSIZE    EQU     8
crosspath_STKGUARD    EQU     1
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
                LDA     #3
                PHA
                FGX2_FARCALL addr_of
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #6
                BNE     *+5
                BRL     _p33_soft_addr_L19
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
_p33_soft_addr_L19
                LDA     #2
                PHA
                FGX2_FARCALL elems
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000F
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
                BNE     *+5
                BRL     _p33_soft_addr_L20
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
_p33_soft_addr_L20
                LDA     #2
                PHA
                FGX2_FARCALL rowsum
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #18
                BNE     *+5
                BRL     _p33_soft_addr_L21
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
_p33_soft_addr_L21
                LDA     #2
                PHA
                FGX2_FARCALL crosspath
                TAY
                PLA
                TYA
                TAX
                TXA
                CMP     #9
                BNE     *+5
                BRL     _p33_soft_addr_L22
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
_p33_soft_addr_L22
                LDA     #42
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
                FGX2_RELOC_COUNT 16
