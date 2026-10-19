                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from sl_buf.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT getbuf
getbuf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getbuf_FRAMESIZE
                DO      getbuf_STKGUARD
                BCC     getbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     getbuf_stkok
getbuf_stkovf       JMP     _fcc_stkoflow
                FIN
getbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #getbuf_sl_buf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #65
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #getbuf_sl_buf
                STA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #getbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getbuf_FRAMESIZE   EQU     0
getbuf_STKGUARD    EQU     0
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
                FGX2_FARCALL getbuf
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
