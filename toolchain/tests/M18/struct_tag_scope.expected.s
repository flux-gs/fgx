                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from struct_tag_scope.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT outer_sum
outer_sum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #outer_sum_FRAMESIZE
                DO      outer_sum_STKGUARD
                BCC     outer_sum_stkovf
                CMP     _fcc_stkfloor
                BCS     outer_sum_stkok
outer_sum_stkovf       JMP     _fcc_stkoflow
                FIN
outer_sum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #3
                STA     1,S   ; fccstk d=0 b=1
                LDA     #4
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #outer_sum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
outer_sum_FRAMESIZE   EQU     4
outer_sum_STKGUARD    EQU     0
                FGX2_EXPORT first
first            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #first_FRAMESIZE
                DO      first_STKGUARD
                BCC     first_stkovf
                CMP     _fcc_stkfloor
                BCS     first_stkok
first_stkovf       JMP     _fcc_stkoflow
                FIN
first_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
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
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #120
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #first_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
first_FRAMESIZE   EQU     4
first_STKGUARD    EQU     0
                FGX2_EXPORT second
second            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #second_FRAMESIZE
                DO      second_STKGUARD
                BCC     second_stkovf
                CMP     _fcc_stkfloor
                BCS     second_stkok
second_stkovf       JMP     _fcc_stkoflow
                FIN
second_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #9
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #121
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                INC
                INC
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #second_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
second_FRAMESIZE   EQU     8
second_STKGUARD    EQU     0
                FGX2_EXPORT shadow_then_outer
shadow_then_outer            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #shadow_then_outer_FRAMESIZE
                DO      shadow_then_outer_STKGUARD
                BCC     shadow_then_outer_stkovf
                CMP     _fcc_stkfloor
                BCS     shadow_then_outer_stkok
shadow_then_outer_stkovf       JMP     _fcc_stkoflow
                FIN
shadow_then_outer_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #100
                STA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img0
                LDA     #1
                STA     5,S   ; fccstk d=0 b=5
                LDA     #2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_img0
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #shadow_then_outer_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
shadow_then_outer_FRAMESIZE   EQU     8
shadow_then_outer_STKGUARD    EQU     0
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
                FGX2_FARCALL outer_sum
                PHA
                FGX2_FARCALL first
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                FGX2_FARCALL second
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                FGX2_FARCALL shadow_then_outer
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
                FGX2_RELOC_COUNT 10
