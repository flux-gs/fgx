                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ret_typedef.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT getmsg
getmsg            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getmsg_FRAMESIZE
                DO      getmsg_STKGUARD
                BCC     getmsg_stkovf
                CMP     _fcc_stkfloor
                BCS     getmsg_stkok
getmsg_stkovf       JMP     _fcc_stkoflow
                FIN
getmsg_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ret_typedef_msg
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #getmsg_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getmsg_FRAMESIZE   EQU     0
getmsg_STKGUARD    EQU     0
                FGX2_EXPORT getbox
getbox            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getbox_FRAMESIZE
                DO      getbox_STKGUARD
                BCC     getbox_stkovf
                CMP     _fcc_stkfloor
                BCS     getbox_stkok
getbox_stkovf       JMP     _fcc_stkoflow
                FIN
getbox_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ret_typedef_box
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #getbox_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getbox_FRAMESIZE   EQU     0
getbox_STKGUARD    EQU     0
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
                LDA     #_ret_typedef_msg
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #40
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
                LDA     #2
                STA     _ret_typedef_box+0
                FGX2_FARCALL getmsg
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                FGX2_FARCALL getbox
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
                FGX2_RELOC_COUNT 6
