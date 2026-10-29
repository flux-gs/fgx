                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from init_nested_local.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT dirty
dirty            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #dirty_FRAMESIZE
                DO      dirty_STKGUARD
                BCC     dirty_stkovf
                CMP     _fcc_stkfloor
                BCS     dirty_stkok
dirty_stkovf       JMP     _fcc_stkoflow
                FIN
dirty_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
_init_nested_local_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #24
                BVC     _init_nested_local_L3
                EOR     #$8000
_init_nested_local_L3
                BPL     _init_nested_local_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     _fcc_img0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #23130
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
                STA     [_fcc_ptr]
                PLA
_init_nested_local_L1
                INC     _fcc_img0
                BRA     _init_nested_local_L0
_init_nested_local_L2
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                PHA
                LDA     #3
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                TAY
                TSC
                CLC
                ADC     #dirty_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
dirty_FRAMESIZE   EQU     50
dirty_STKGUARD    EQU     0
                FGX2_EXPORT check
check            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #check_FRAMESIZE
                DO      check_STKGUARD
                BCC     check_stkovf
                CMP     _fcc_stkfloor
                BCS     check_stkok
check_stkovf       JMP     _fcc_stkoflow
                FIN
check_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                STA     3,S   ; fccstk d=0 b=3
                LDA     #2
                STA     5,S   ; fccstk d=0 b=5
                LDA     #3
                STA     7,S   ; fccstk d=0 b=7
                LDA     #4
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     11,S   ; fccstk d=0 b=11
                LDA     #1
                STA     13,S   ; fccstk d=0 b=13
                LDA     #2
                STA     15,S   ; fccstk d=0 b=15
                LDA     #3
                STA     17,S   ; fccstk d=0 b=17
                LDA     #4
                STA     19,S   ; fccstk d=0 b=19
                LDA     #5
                STA     21,S   ; fccstk d=0 b=21
                LDA     #9
                STA     23,S   ; fccstk d=0 b=23
                LDA     #0
                SEP     #$20
                MX      %10
                STA     25,S   ; fccstk d=0 b=25
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     26,S   ; fccstk d=0 b=26
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     27,S   ; fccstk d=0 b=27
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     28,S   ; fccstk d=0 b=28
                REP     #$20
                MX      %00
                LDA     #0
                STA     29,S   ; fccstk d=0 b=29
                LDA     #0
                STA     31,S   ; fccstk d=0 b=31
                LDA     #9
                STA     33,S   ; fccstk d=0 b=33
                LDA     #97
                SEP     #$20
                MX      %10
                STA     35,S   ; fccstk d=0 b=35
                REP     #$20
                MX      %00
                LDA     #98
                SEP     #$20
                MX      %10
                STA     36,S   ; fccstk d=0 b=36
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     37,S   ; fccstk d=0 b=37
                REP     #$20
                MX      %00
                LDA     #0
                SEP     #$20
                MX      %10
                STA     38,S   ; fccstk d=0 b=38
                REP     #$20
                MX      %00
                LDA     #6
                STA     39,S   ; fccstk d=0 b=39
                LDA     #0
                STA     41,S   ; fccstk d=0 b=41
                LDA     #0
                STA     _fcc_img0
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #1
                BNE     _init_nested_local_L5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #3
                BNE     _init_nested_local_L5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                INC
                INC
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #4
                BNE     _init_nested_local_L5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                INC
                INC
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _init_nested_local_L4
_init_nested_local_L5
                INC     _fcc_img0
_init_nested_local_L4
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #2
                BNE     _init_nested_local_L7
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                INC
                INC
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #4
                BNE     _init_nested_local_L7
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #12
                INC
                INC
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #5
                BEQ     _init_nested_local_L6
_init_nested_local_L7
                INC     _fcc_img0
_init_nested_local_L6
                LDA     23,S   ; fccstk d=0 b=23
                CMP     #9
                BNE     _init_nested_local_L9
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BNE     _init_nested_local_L9
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                INC
                INC
                CLC
                ADC     #3
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BNE     _init_nested_local_L9
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BNE     _init_nested_local_L9
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #22
                CLC
                ADC     #6
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _init_nested_local_L8
_init_nested_local_L9
                INC     _fcc_img0
_init_nested_local_L8
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #32
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #98
                BNE     _init_nested_local_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #32
                INC
                INC
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BNE     _init_nested_local_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #32
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #6
                BNE     _init_nested_local_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #32
                CLC
                ADC     #6
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BEQ     _init_nested_local_L10
_init_nested_local_L11
                INC     _fcc_img0
_init_nested_local_L10
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #check_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
check_FRAMESIZE   EQU     42
check_STKGUARD    EQU     0
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
                FGX2_FARCALL dirty
                FGX2_FARCALL check
                STA     1,S   ; fccstk d=0 b=1
                CMP     #0
                BEQ     _init_nested_local_L12
                LDA     1,S   ; fccstk d=0 b=1
                BRA     _init_nested_local_L13
_init_nested_local_L12
                LDA     #42
_init_nested_local_L13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
