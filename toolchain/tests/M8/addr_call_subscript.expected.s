                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from addr_call_subscript.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pb
pb            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pb_FRAMESIZE
                DO      pb_STKGUARD
                BCC     pb_stkovf
                CMP     _fcc_stkfloor
                BCS     pb_stkok
pb_stkovf       JMP     _fcc_stkoflow
                FIN
pb_stkok        TCS
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
                LDA     #_addr_call_subscript_buf
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #pb_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pb_FRAMESIZE   EQU     0
pb_STKGUARD    EQU     0
                FGX2_EXPORT ps
ps            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ps_FRAMESIZE
                DO      ps_STKGUARD
                BCC     ps_stkovf
                CMP     _fcc_stkfloor
                BCS     ps_stkok
ps_stkovf       JMP     _fcc_stkoflow
                FIN
ps_stkok        TCS
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
                LDA     #_addr_call_subscript_arr
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #ps_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ps_FRAMESIZE   EQU     0
ps_STKGUARD    EQU     0
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
                FGX2_FARCALL pb
                LDA     _fcc_fpr0
                CLC
                ADC     #3
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL ps
                LDA     _fcc_fpr0
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                FGX2_FARCALL ps
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #30
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0
                LDA     #7
                STA     [_fcc_fpr0]
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_fpr0
                LDA     #5
                STA     [_fcc_fpr0]
                LDA     #3
                TAX
                LDA:    _addr_call_subscript_buf,X
                AND     #$00FF
                PHA
                LDA     #2
                ASL
                ASL
                CLC
                ADC     #_addr_call_subscript_arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #_addr_call_subscript_arr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 7
