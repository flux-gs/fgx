                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from chain_structcopy.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g2
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #mk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
mk_FRAMESIZE   EQU     0
mk_STKGUARD    EQU     0
                FGX2_EXPORT _chain_structcopy_same
_chain_structcopy_same            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_chain_structcopy_same_FRAMESIZE
                DO      _chain_structcopy_same_STKGUARD
                BCC     _chain_structcopy_same_stkovf
                CMP     _fcc_stkfloor
                BCS     _chain_structcopy_same_stkok
_chain_structcopy_same_stkovf       JMP     _fcc_stkoflow
                FIN
_chain_structcopy_same_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_chain_structcopy_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_chain_structcopy_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_chain_structcopy_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_chain_structcopy_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_chain_structcopy_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_chain_structcopy_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                DO      12+_chain_structcopy_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_chain_structcopy_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_chain_structcopy_same_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _chain_structcopy_L2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                DO      14+_chain_structcopy_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_chain_structcopy_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_chain_structcopy_same_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _chain_structcopy_L2
                LDA     #1
                BRA     _chain_structcopy_L3
_chain_structcopy_L2
                LDA     #0
_chain_structcopy_L3
                CMP     #0
                BEQ     _chain_structcopy_L0
                DO      8+_chain_structcopy_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_chain_structcopy_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_chain_structcopy_same_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_chain_structcopy_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_chain_structcopy_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_chain_structcopy_same_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #4
                LDA     [_fcc_fpr0],Y
                PHA
                DO      16+_chain_structcopy_same_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_chain_structcopy_same_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_chain_structcopy_same_FRAMESIZE,S   ; fccstk d=2 b=14 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _chain_structcopy_L0
                LDA     #1
                BRA     _chain_structcopy_L1
_chain_structcopy_L0
                LDA     #0
_chain_structcopy_L1
                TAY
                TSC
                CLC
                ADC     #_chain_structcopy_same_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_chain_structcopy_same_FRAMESIZE   EQU     0
_chain_structcopy_same_STKGUARD    EQU     0
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     #11
                STA     _chain_structcopy_iv+0
                LDA     #22
                STA     _chain_structcopy_iv+2
                LDA     #33
                STA     _chain_structcopy_iv+4
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g1
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _chain_structcopy_g0+10
                TAY
                LDA     _fcc_ptr+2
                STA     _chain_structcopy_g0+12
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g3
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _chain_structcopy_g1+10
                TAY
                LDA     _fcc_ptr+2
                STA     _chain_structcopy_g1+12
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g0
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     _chain_structcopy_gp
                LDA     _fcc_fpr0+2
                STA     _chain_structcopy_gp+2
                LDA     #5
                STA     _chain_structcopy_g1+0
                LDA     #6
                STA     _chain_structcopy_g1+8
                LDA     #7
                STA     _chain_structcopy_g2+0
                LDA     #8
                STA     _chain_structcopy_g2+8
                LDA     #9
                STA     _chain_structcopy_g3+0
                LDA     #10
                STA     _chain_structcopy_g3+8
                SEP     #$20
                MX      %10
                LDA     _chain_structcopy_g0+12
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _chain_structcopy_g0+10
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_iv
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_chain_structcopy_L4
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _chain_structcopy_L4
                LDA     #33
                PHA
                LDA     #22
                PHA
                LDA     #11
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g1+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _chain_structcopy_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BEQ     _chain_structcopy_L8
                LDA     _chain_structcopy_g1+0
                TAX
                CMP     #5
                BNE     _chain_structcopy_L8
                LDA     #1
                BRA     _chain_structcopy_L9
_chain_structcopy_L8
                LDA     #0
_chain_structcopy_L9
                CMP     #0
                BEQ     _chain_structcopy_L6
                LDA     _chain_structcopy_g1+8
                TAX
                CMP     #6
                BNE     _chain_structcopy_L6
                LDA     #1
                BRA     _chain_structcopy_L7
_chain_structcopy_L6
                LDA     #0
_chain_structcopy_L7
                CMP     #0
                BEQ     _chain_structcopy_L5
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #6
                STA     3,S   ; fccstk d=0 b=3
_chain_structcopy_L5
                LDA     #44
                STA     _chain_structcopy_iv+0
                SEP     #$20
                MX      %10
                LDA     _chain_structcopy_gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _chain_structcopy_gp
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_iv
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_chain_structcopy_L10
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _chain_structcopy_L10
                LDA     #33
                PHA
                LDA     #22
                PHA
                LDA     #44
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g3+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _chain_structcopy_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BEQ     _chain_structcopy_L14
                LDA     _chain_structcopy_g3+0
                TAX
                CMP     #9
                BNE     _chain_structcopy_L14
                LDA     #1
                BRA     _chain_structcopy_L15
_chain_structcopy_L14
                LDA     #0
_chain_structcopy_L15
                CMP     #0
                BEQ     _chain_structcopy_L12
                LDA     _chain_structcopy_g3+8
                TAX
                CMP     #10
                BNE     _chain_structcopy_L12
                LDA     #1
                BRA     _chain_structcopy_L13
_chain_structcopy_L12
                LDA     #0
_chain_structcopy_L13
                CMP     #0
                BEQ     _chain_structcopy_L11
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #6
                STA     3,S   ; fccstk d=0 b=3
_chain_structcopy_L11
                LDA     #55
                STA     _chain_structcopy_iv+2
                SEP     #$20
                MX      %10
                LDA     _chain_structcopy_gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _chain_structcopy_gp
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_iv
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_chain_structcopy_L16
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _chain_structcopy_L16
                LDA     #33
                PHA
                LDA     #55
                PHA
                LDA     #44
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g1+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _chain_structcopy_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BEQ     _chain_structcopy_L18
                LDA     _chain_structcopy_g1+8
                TAX
                CMP     #6
                BNE     _chain_structcopy_L18
                LDA     #1
                BRA     _chain_structcopy_L19
_chain_structcopy_L18
                LDA     #0
_chain_structcopy_L19
                CMP     #0
                BEQ     _chain_structcopy_L17
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #6
                STA     3,S   ; fccstk d=0 b=3
_chain_structcopy_L17
                LDA     #66
                STA     _chain_structcopy_iv+4
                FGX2_FARCALL mk
                LDA     _fcc_fpr0
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_iv
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_chain_structcopy_L20
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _chain_structcopy_L20
                LDA     #66
                PHA
                LDA     #55
                PHA
                LDA     #44
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g2+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _chain_structcopy_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BEQ     _chain_structcopy_L24
                LDA     _chain_structcopy_g2+0
                TAX
                CMP     #7
                BNE     _chain_structcopy_L24
                LDA     #1
                BRA     _chain_structcopy_L25
_chain_structcopy_L24
                LDA     #0
_chain_structcopy_L25
                CMP     #0
                BEQ     _chain_structcopy_L22
                LDA     _chain_structcopy_g2+8
                TAX
                CMP     #8
                BNE     _chain_structcopy_L22
                LDA     #1
                BRA     _chain_structcopy_L23
_chain_structcopy_L22
                LDA     #0
_chain_structcopy_L23
                CMP     #0
                BEQ     _chain_structcopy_L21
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #6
                STA     3,S   ; fccstk d=0 b=3
_chain_structcopy_L21
                LDA     #77
                STA     _chain_structcopy_iv+0
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     _chain_structcopy_gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _chain_structcopy_gp
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_iv
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_chain_structcopy_L26
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _chain_structcopy_L26
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #1
                BNE     _chain_structcopy_L30
                LDA     #66
                PHA
                LDA     #55
                PHA
                LDA     #77
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g3+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _chain_structcopy_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BEQ     _chain_structcopy_L30
                LDA     #1
                BRA     _chain_structcopy_L31
_chain_structcopy_L30
                LDA     #0
_chain_structcopy_L31
                CMP     #0
                BEQ     _chain_structcopy_L28
                LDA     _chain_structcopy_g3+8
                TAX
                CMP     #10
                BNE     _chain_structcopy_L28
                LDA     #1
                BRA     _chain_structcopy_L29
_chain_structcopy_L28
                LDA     #0
_chain_structcopy_L29
                CMP     #0
                BEQ     _chain_structcopy_L27
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #6
                STA     3,S   ; fccstk d=0 b=3
_chain_structcopy_L27
                LDA     #88
                STA     _chain_structcopy_iv+2
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     _chain_structcopy_gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _chain_structcopy_gp
                STA     _fcc_fpr0
                LDY     #10
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #12
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                CLC
                ADC     #2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_iv
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #4
_chain_structcopy_L32
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _chain_structcopy_L32
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CMP     #2
                BNE     _chain_structcopy_L34
                LDA     #66
                PHA
                LDA     #88
                PHA
                LDA     #77
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_g1+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _chain_structcopy_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BEQ     _chain_structcopy_L34
                LDA     #1
                BRA     _chain_structcopy_L35
_chain_structcopy_L34
                LDA     #0
_chain_structcopy_L35
                CMP     #0
                BEQ     _chain_structcopy_L33
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #6
                STA     3,S   ; fccstk d=0 b=3
_chain_structcopy_L33
                LDA     #66
                PHA
                LDA     #88
                PHA
                LDA     #77
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_chain_structcopy_iv
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _chain_structcopy_same
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                BEQ     _chain_structcopy_L36
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #6
                STA     3,S   ; fccstk d=0 b=3
_chain_structcopy_L36
                LDA     3,S   ; fccstk d=0 b=3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 12
