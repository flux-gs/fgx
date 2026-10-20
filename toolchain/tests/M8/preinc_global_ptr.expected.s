                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from preinc_global_ptr.c
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
                LDA     #str
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
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
                LDA     #str
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #14
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
                LDA     #str
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #28
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
                LDA     #str
                STA     cursor
                LDA     _fcc_fpr0+2
                STA     cursor+2
                SEP     #$20
                MX      %10
                LDA     cursor+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     cursor
                INC
                STA     cursor
                TAY
                LDA     _fcc_ptr+2
                STA     cursor+2
                TYA
                SEP     #$20
                MX      %10
                LDA     cursor+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     cursor
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     cursor+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     cursor
                INC
                STA     cursor
                TAY
                LDA     _fcc_ptr+2
                STA     cursor+2
                TYA
                LDA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                LDA     cursor+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     cursor
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     cursor+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     cursor
                DEC
                STA     cursor
                TAY
                LDA     _fcc_ptr+2
                STA     cursor+2
                TYA
                SEP     #$20
                MX      %10
                LDA     cursor+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     cursor
                DEC
                STA     cursor
                TAY
                LDA     _fcc_ptr+2
                STA     cursor+2
                TYA
                LDA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                LDA     cursor+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     cursor
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
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
                FGX2_RELOC_COUNT 2
