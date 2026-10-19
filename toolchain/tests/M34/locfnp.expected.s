                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from locfnp.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT f2
f2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f2_FRAMESIZE
                DO      f2_STKGUARD
                BCC     f2_stkovf
                CMP     _fcc_stkfloor
                BCS     f2_stkok
f2_stkovf       JMP     _fcc_stkoflow
                FIN
f2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #f2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f2_FRAMESIZE   EQU     0
f2_STKGUARD    EQU     0
                FGX2_EXPORT add8
add8            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #add8_FRAMESIZE
                DO      add8_STKGUARD
                BCC     add8_stkovf
                CMP     _fcc_stkfloor
                BCS     add8_stkok
add8_stkovf       JMP     _fcc_stkoflow
                FIN
add8_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+add8_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+add8_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+add8_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #add8_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
add8_FRAMESIZE   EQU     0
add8_STKGUARD    EQU     0
                FGX2_EXPORT f30
f30            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #f30_FRAMESIZE
                DO      f30_STKGUARD
                BCC     f30_stkovf
                CMP     _fcc_stkfloor
                BCS     f30_stkok
f30_stkovf       JMP     _fcc_stkoflow
                FIN
f30_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #f30_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
f30_FRAMESIZE   EQU     0
f30_STKGUARD    EQU     0
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
                STA     13,S   ; fccstk d=0 b=13
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                LDA     _locfnp_FA0+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _locfnp_FA0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_ptr+2
                STA     _fcc_tmp_b
                TYA
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
                LDA     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                LDA     _locfnp_FA1+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _locfnp_FA1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_ptr+2
                STA     _fcc_tmp_b
                TYA
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
                LDA     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #20
                PHA
                LDA     3,S
                STA     _fcc_fpr0
                LDA     5,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _locfnp_L2-1
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
_locfnp_L2
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
                STA     13,S   ; fccstk d=0 b=13
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
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
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     13,S   ; fccstk d=2 b=11
                STA     _fcc_fpr0+2
                LDA     11,S   ; fccstk d=2 b=9
                STA     _fcc_fpr0
                PHK
                PEA     _locfnp_L3-1
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
_locfnp_L3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
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
                LDA     _locfnp_FA4+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _locfnp_FA4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_ptr+2
                STA     _fcc_tmp_b
                TYA
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
                LDA     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                LDA     _fcc_fb
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
                SEP     #$20
                MX      %10
                LDA     _locfnp_FA5+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _locfnp_FA5
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_ptr+2
                STA     _fcc_tmp_b
                TYA
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
                LDA     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     _fcc_fb
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
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     1,S
                STA     _fcc_fpr0
                LDA     3,S
                STA     _fcc_fpr0+2
                PHK
                PEA     _locfnp_L6-1
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
_locfnp_L6
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
                STA     13,S   ; fccstk d=0 b=13
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #14
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
                LDA     #b1
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_ptr+2
                STA     _fcc_tmp_b
                TYA
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
                LDA     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                LDA     _fcc_fb
                CLC
                ADC     #14
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
                LDA     #b2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_ptr+2
                STA     _fcc_tmp_b
                TYA
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
                LDA     _fcc_tmp_b
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                LDA     #b2
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     13,S   ; fccstk d=0 b=13
                PHA
                LDA     _fcc_fb
                CLC
                ADC     #14
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
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
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
                LDA     #20
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     13,S   ; fccstk d=0 b=13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     26
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 5
