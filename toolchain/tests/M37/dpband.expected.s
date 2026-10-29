                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from dpband.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT leaf
leaf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #leaf_FRAMESIZE
                DO      leaf_STKGUARD
                BCC     leaf_stkovf
                CMP     _fcc_stkfloor
                BCS     leaf_stkok
leaf_stkovf       JMP     _fcc_stkoflow
                FIN
leaf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     calls
                INC
                STA     calls
                DO      6+leaf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+leaf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+leaf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                AND     #1
                TAY
                TSC
                CLC
                ADC     #leaf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
leaf_FRAMESIZE   EQU     0
leaf_STKGUARD    EQU     0
                FGX2_EXPORT walk
walk            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #walk_FRAMESIZE-8
                DO      walk_STKGUARD
                BCC     walk_stkovf
                CMP     _fcc_stkfloor
                BCS     walk_stkok
walk_stkovf       JMP     _fcc_stkoflow
                FIN
walk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img19
                DO      8+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+walk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+walk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     _fcc_img18
_dpband_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                TAX
                DO      10+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+walk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _dpband_L3
                EOR     #$8000
_dpband_L3
                BPL     _dpband_L2
                LDA     _fcc_img19
                PHA
                LDA     [_fcc_img16]
                AND     #$00FF
                PHA
                FGX2_FARCALL leaf
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                CLC
                ADC     #1
                STA     _fcc_img16
_dpband_L1
                INC     _fcc_img18
                BRA     _dpband_L0
_dpband_L2
                LDA     _fcc_img19
                TAY
                TSC
                CLC
                ADC     #walk_FRAMESIZE-8
                TCS
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
walk_FRAMESIZE   EQU     16
walk_STKGUARD    EQU     0
                FGX2_EXPORT sum
sum            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #sum_FRAMESIZE-8
                DO      sum_STKGUARD
                BCC     sum_stkovf
                CMP     _fcc_stkfloor
                BCS     sum_stkok
sum_stkovf       JMP     _fcc_stkoflow
                FIN
sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img18
                DO      8+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+sum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     _fcc_img19
_dpband_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img19
                TAX
                SEC
                SBC     #8
                BVC     _dpband_L7
                EOR     #$8000
_dpband_L7
                BPL     _dpband_L6
                LDA     _fcc_img18
                PHA
                LDA     _fcc_img19
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #s2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL walk
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
                PHA
                LDA     [_fcc_img16]
                AND     #$00FF
                TAX
                AND     #7
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img18
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                CLC
                ADC     #1
                STA     _fcc_img16
_dpband_L5
                INC     _fcc_img19
                BRA     _dpband_L4
_dpband_L6
                LDA     _fcc_img18
                TAY
                TSC
                CLC
                ADC     #sum_FRAMESIZE-8
                TCS
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
sum_FRAMESIZE   EQU     16
sum_STKGUARD    EQU     0
                FGX2_EXPORT rec
rec            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #rec_FRAMESIZE
                DO      rec_STKGUARD
                BCC     rec_stkovf
                CMP     _fcc_stkfloor
                BCS     rec_stkok
rec_stkovf       JMP     _fcc_stkoflow
                FIN
rec_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                DO      8+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+rec_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+rec_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     7,S   ; fccstk d=0 b=7
_dpband_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                SEC
                SBC     #2
                BVC     _dpband_L11
                EOR     #$8000
_dpband_L11
                BMI     *+5
                BRL     _dpband_L10
                DO      10+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+rec_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CMP     #0
                BEQ     _dpband_L12
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                DO      12+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+rec_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                TAX
                DEC
                PHA
                DO      12+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+rec_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+rec_FRAMESIZE,S   ; fccstk d=4 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL rec
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
                STA     5,S   ; fccstk d=0 b=5
_dpband_L12
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_ptr
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
_dpband_L9
                LDA     7,S   ; fccstk d=0 b=7
                CLC
                ADC     #1
                STA     7,S   ; fccstk d=0 b=7
                BRL     _dpband_L8
_dpband_L10
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #rec_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
rec_FRAMESIZE   EQU     8
rec_STKGUARD    EQU     1
                FGX2_EXPORT jumper
jumper            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #jumper_FRAMESIZE
                DO      jumper_STKGUARD
                BCC     jumper_stkovf
                CMP     _fcc_stkfloor
                BCS     jumper_stkok
jumper_stkovf       JMP     _fcc_stkoflow
                FIN
jumper_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #env
                PHA
                LDA     #3
                PLX
                FGX2_FARCALL longjmp
                TAY
                TSC
                CLC
                ADC     #jumper_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
jumper_FRAMESIZE   EQU     0
jumper_STKGUARD    EQU     0
                FGX2_EXPORT deep
deep            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #deep_FRAMESIZE-8
                DO      deep_STKGUARD
                BCC     deep_stkovf
                CMP     _fcc_stkfloor
                BCS     deep_stkok
deep_stkovf       JMP     _fcc_stkoflow
                FIN
deep_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img19
                DO      8+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+deep_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+deep_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+deep_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+deep_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     _fcc_img18
_dpband_L13
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                TAX
                SEC
                SBC     #4
                BVC     _dpband_L16
                EOR     #$8000
_dpband_L16
                BPL     _dpband_L15
                LDA     _fcc_img19
                PHA
                LDA     [_fcc_img16]
                INC     _fcc_img16
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                LDA     _fcc_img18
                TAX
                CMP     #2
                BNE     _dpband_L17
                FGX2_FARCALL jumper
_dpband_L17
                LDA     _fcc_img19
                PHA
                FGX2_FARCALL leaf
                TAY
                PLA
                TYA
_dpband_L14
                INC     _fcc_img18
                BRA     _dpband_L13
_dpband_L15
                LDA     _fcc_img19
                TAY
                TSC
                CLC
                ADC     #deep_FRAMESIZE-8
                TCS
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
deep_FRAMESIZE   EQU     16
deep_STKGUARD    EQU     0
                FGX2_EXPORT outer
outer            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #outer_FRAMESIZE-8
                DO      outer_STKGUARD
                BCC     outer_stkovf
                CMP     _fcc_stkfloor
                BCS     outer_stkok
outer_stkovf       JMP     _fcc_stkoflow
                FIN
outer_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+outer_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+outer_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+outer_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+outer_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+outer_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+outer_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #env
                TAX
                FGX2_FARCALL setjmp
                STA     9,S   ; fccstk d=0 b=9
                LDA     #0
                STA     _fcc_img19
                LDA     #0
                STA     _fcc_img18
_dpband_L18
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                TAX
                SEC
                SBC     #4
                BVC     _dpband_L21
                EOR     #$8000
_dpband_L21
                BPL     _dpband_L20
                LDA     _fcc_img19
                PHA
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     _fcc_img18
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
                STA     _fcc_img19
                LDA     9,S   ; fccstk d=0 b=9
                CMP     #0
                BNE     _dpband_L22
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #s2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL deep
                TSC
                CLC
                ADC     #4
                TCS
_dpband_L22
                LDA     _fcc_img18
                PHA
                FGX2_FARCALL leaf
                TAY
                PLA
                TYA
_dpband_L19
                INC     _fcc_img18
                BRA     _dpband_L18
_dpband_L20
                LDA     _fcc_img19
                CLC
                ADC     9,S   ; fccstk d=0 b=9
                TAY
                TSC
                CLC
                ADC     #outer_FRAMESIZE-8
                TCS
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
outer_FRAMESIZE   EQU     18
outer_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #main_FRAMESIZE-8
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
                STA     7,S   ; fccstk d=0 b=7
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #s1
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #0
                STA     _fcc_img19
                LDA     #0
                STA     _fcc_img18
_dpband_L23
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img18
                TAX
                SEC
                SBC     #3
                BVC     _dpband_L26
                EOR     #$8000
_dpband_L26
                BPL     _dpband_L25
                LDA     _fcc_img19
                PHA
                LDA     [_fcc_img16]
                INC     _fcc_img16
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img19
                LDA     _fcc_img18
                PHA
                FGX2_FARCALL leaf
                TAY
                PLA
                TYA
_dpband_L24
                INC     _fcc_img18
                BRA     _dpband_L23
_dpband_L25
                LDA     _fcc_img19
                TAX
                LDA     #97
                TAY
                TYA
                CLC
                ADC     #98
                TAY
                TYA
                CLC
                ADC     #99
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _dpband_L27
                LDA     [_fcc_img16]
                AND     #$00FF
                TAX
                CMP     #100
                BNE     _dpband_L27
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #10
                STA     7,S   ; fccstk d=0 b=7
_dpband_L27
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #s1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sum
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                CMP     #44
                BNE     _dpband_L28
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #10
                STA     7,S   ; fccstk d=0 b=7
_dpband_L28
                LDA     #3
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #s1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL rec
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #2993
                BNE     _dpband_L29
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #10
                STA     7,S   ; fccstk d=0 b=7
_dpband_L29
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #s1
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL outer
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                PHA
                LDA     #97
                CLC
                ADC     #98
                CLC
                ADC     #99
                CLC
                ADC     #100
                TAX
                CLC
                ADC     #3
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _dpband_L30
                LDA     [_fcc_img16]
                AND     #$00FF
                TAX
                CMP     #100
                BNE     _dpband_L30
                LDA     7,S   ; fccstk d=0 b=7
                TAX
                CLC
                ADC     #12
                STA     7,S   ; fccstk d=0 b=7
_dpband_L30
                LDA     7,S   ; fccstk d=0 b=7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 22
