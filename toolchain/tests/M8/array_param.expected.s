                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from array_param.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _array_param_sum
_array_param_sum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_array_param_sum_FRAMESIZE
                DO      _array_param_sum_STKGUARD
                BCC     _array_param_sum_stkovf
                CMP     _fcc_stkfloor
                BCS     _array_param_sum_stkok
_array_param_sum_stkovf       JMP     _fcc_stkoflow
                FIN
_array_param_sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_array_param_sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_array_param_sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_array_param_sum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_array_param_sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_array_param_sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_array_param_sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                PHA
                DO      10+_array_param_sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_array_param_sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_array_param_sum_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      8+_array_param_sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_array_param_sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_array_param_sum_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
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
                TAY
                TSC
                CLC
                ADC     #_array_param_sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_array_param_sum_FRAMESIZE   EQU     0
_array_param_sum_STKGUARD    EQU     0
                FGX2_EXPORT _array_param_pick
_array_param_pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_array_param_pick_FRAMESIZE
                DO      _array_param_pick_STKGUARD
                BCC     _array_param_pick_stkovf
                CMP     _fcc_stkfloor
                BCS     _array_param_pick_stkok
_array_param_pick_stkovf       JMP     _fcc_stkoflow
                FIN
_array_param_pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_array_param_pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_array_param_pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_array_param_pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_array_param_pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_array_param_pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_array_param_pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                DO      12+_array_param_pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_array_param_pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_array_param_pick_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
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
                LDA     #48
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_array_param_pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_array_param_pick_FRAMESIZE   EQU     0
_array_param_pick_STKGUARD    EQU     0
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
                LDA     #arr
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #20
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #arr
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #15
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #strs
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_array_param_S0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                LDA     #strs
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_array_param_S1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA:    $0002,X
                REP     #$20
                MX      %00
                PLA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _array_param_sum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PHA
                LDA     #0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #strs
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _array_param_pick
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
                FGX2_RELOC_COUNT 6
