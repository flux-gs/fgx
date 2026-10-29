                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from call_postfix.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT getn
getn            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getn_FRAMESIZE
                DO      getn_STKGUARD
                BCC     getn_stkovf
                CMP     _fcc_stkfloor
                BCS     getn_stkok
getn_stkovf       JMP     _fcc_stkoflow
                FIN
getn_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+getn_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+getn_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+getn_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #0
                BEQ     _call_postfix_L0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #n1
                STA     _fcc_fpr0
                PLA
                BRA     _call_postfix_L1
_call_postfix_L0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #n0
                STA     _fcc_fpr0
                PLA
_call_postfix_L1
                TAY
                TSC
                CLC
                ADC     #getn_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getn_FRAMESIZE   EQU     0
getn_STKGUARD    EQU     0
                FGX2_EXPORT getarr
getarr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getarr_FRAMESIZE
                DO      getarr_STKGUARD
                BCC     getarr_stkovf
                CMP     _fcc_stkfloor
                BCS     getarr_stkok
getarr_stkovf       JMP     _fcc_stkoflow
                FIN
getarr_stkok        TCS
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
                LDA     #garr
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #getarr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getarr_FRAMESIZE   EQU     0
getarr_STKGUARD    EQU     0
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
                LDA     #10
                STA     n0+0
                LDA     #30
                STA     n1+0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #n1
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     n0+6
                TAY
                LDA     _fcc_ptr+2
                STA     n0+8
                TYA
                LDA     #0
                CLC
                ADC     #n0+2
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #90
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #garr
                PHA
                LDA     #2
                ASL
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
                STA:    $0000,X
                PLA
                LDA     #0
                PHA
                FGX2_FARCALL getn
                TAY
                PLA
                TYA
                LDA     [_fcc_fpr0]
                TAX
                CMP     #10
                BEQ     _call_postfix_L2
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
_call_postfix_L2
                LDA     #0
                PHA
                FGX2_FARCALL getn
                TAY
                PLA
                TYA
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #30
                BEQ     _call_postfix_L3
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
_call_postfix_L3
                LDA     #0
                PHA
                FGX2_FARCALL getn
                TAY
                PLA
                TYA
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                CMP     #90
                BEQ     _call_postfix_L4
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
_call_postfix_L4
                FGX2_FARCALL getarr
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #2
                BEQ     _call_postfix_L5
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
_call_postfix_L5
                LDA     #0
                PHA
                FGX2_FARCALL getn
                TAY
                PLA
                TYA
                LDA     [_fcc_fpr0]
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL getn
                TAY
                PLA
                TYA
                LDY     #6
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #8
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                FGX2_FARCALL getarr
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
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
                FGX2_RELOC_COUNT 11
