                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fn_param_knr2.c
;---------------------------------------

                MX      %00
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
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fn_param_knr2_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_fn_param_knr2_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fn_param_knr2_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fn_param_knr2_FA0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL call
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
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
                FGX2_EXPORT use
use            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #use_FRAMESIZE
                DO      use_STKGUARD
                BCC     use_stkovf
                CMP     _fcc_stkfloor
                BCS     use_stkok
use_stkovf       JMP     _fcc_stkoflow
                FIN
use_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+use_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+use_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+use_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                PHA
                DO      12+use_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+use_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+use_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+use_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+use_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+use_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                SEC
                SBC     #97
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      12+use_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+use_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+use_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_ptr+2
                DO      10+use_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+use_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+use_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                SEC
                SBC     #97
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #use_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
use_FRAMESIZE   EQU     0
use_STKGUARD    EQU     0
                FGX2_EXPORT call
call            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #call_FRAMESIZE
                DO      call_STKGUARD
                BCC     call_stkovf
                CMP     _fcc_stkfloor
                BCS     call_stkok
call_stkovf       JMP     _fcc_stkoflow
                FIN
call_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #10+call_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
_fn_param_knr2_L1
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                CLC
                ADC     #4
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _fn_param_knr2_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _fn_param_knr2_L4
                LDA     #0
                BRA     _fn_param_knr2_L5
_fn_param_knr2_L4
                LDA     #1
_fn_param_knr2_L5
                CMP     #0
                BEQ     _fn_param_knr2_L3
_fn_param_knr2_L2
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
                BRA     _fn_param_knr2_L1
_fn_param_knr2_L3
                DO      8+call_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+call_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+call_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+call_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+call_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+call_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #14+call_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     13,S   ; fccstk d=8 b=5
                PHA
                LDA     7,S
                STA     _fcc_fpr0
                LDA     9,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _fn_param_knr2_L6-1
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
_fn_param_knr2_L6
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAY
                TSC
                CLC
                ADC     #call_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
call_FRAMESIZE   EQU     6
call_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 5
