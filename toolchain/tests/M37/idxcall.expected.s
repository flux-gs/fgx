                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from idxcall.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT via
via            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #via_FRAMESIZE
                DO      via_STKGUARD
                BCC     via_stkovf
                CMP     _fcc_stkfloor
                BCS     via_stkok
via_stkovf       JMP     _fcc_stkoflow
                FIN
via_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                DO      8+via_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+via_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+via_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
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
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     [_fcc_img0]
                INC     _fcc_img0
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #via_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
via_FRAMESIZE   EQU     6
via_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_idxcall_digs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_idxcall_nums
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_idxcall_lnum
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_idxcall_strs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     17,S   ; fccstk d=0 b=17
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #7
                PHA
                FGX2_FARCALL via
                TAY
                PLA
                TYA
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #55
                BNE     _idxcall_L0
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #10
                STA     17,S   ; fccstk d=0 b=17
_idxcall_L0
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL via
                TAY
                PLA
                TYA
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                TAX
                CMP     #12
                BNE     _idxcall_L1
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #10
                STA     17,S   ; fccstk d=0 b=17
_idxcall_L1
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL via
                TAY
                PLA
                TYA
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                TAY
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                TYA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                CLC
                ADC     #2
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                LDX     #4465
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _idxcall_L2
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #10
                STA     17,S   ; fccstk d=0 b=17
_idxcall_L2
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL via
                TAY
                PLA
                TYA
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                TAY
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                TYA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #99
                BNE     _idxcall_L3
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #5
                STA     17,S   ; fccstk d=0 b=17
_idxcall_L3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL via
                TAY
                PLA
                TYA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #120
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     #3
                TAX
                LDA:    _idxcall_digs,X
                AND     #$00FF
                TAX
                CMP     #120
                BNE     _idxcall_L4
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #4
                STA     17,S   ; fccstk d=0 b=17
_idxcall_L4
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gp
                PHA
                LDA     #4
                PHA
                FGX2_FARCALL via
                TAY
                PLA
                TYA
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #121
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     #4
                TAX
                LDA:    _idxcall_digs,X
                AND     #$00FF
                TAX
                CMP     #121
                BNE     _idxcall_L5
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                CLC
                ADC     #3
                STA     17,S   ; fccstk d=0 b=17
_idxcall_L5
                LDA     17,S   ; fccstk d=0 b=17
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
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 9
