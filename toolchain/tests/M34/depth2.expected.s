                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from depth2.c
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
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbuf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gs
                LDA     _fcc_fpr0+2
                STA     gs+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gd+0
                TAY
                LDA     _fcc_ptr+2
                STA     gd+2
                TYA
                LDA     #gbuf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #10
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
                LDA     _fcc_img0
                PHA
                LDA     gd+2
                STA     _fcc_fpr0+2
                LDA     gd+0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                LDA     #b2
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #7
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
                LDA     gd+2
                STA     _fcc_fpr0+2
                LDA     gd+0
                STA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #b2
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #2
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     _fcc_img0
                PHA
                LDA     #0
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gs+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gs
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbuf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gs
                LDA     _fcc_fpr0+2
                STA     gs+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gpp
                LDA     _fcc_fpr0+2
                STA     gpp+2
                LDA     #gbuf
                PHA
                LDA     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #9
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
                LDA     gpp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gpp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CLC
                ADC     #3
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                PHA
                LDA     #0
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gs+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gs
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gbuf
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gs
                LDA     _fcc_fpr0+2
                STA     gs+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gv
                LDA     _fcc_fpr0+2
                STA     gv+2
                LDA     #gbuf
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #6
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
                LDA     gv+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gv
                STA     gpp
                LDA     _fcc_fpr0+2
                STA     gpp+2
                LDA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                LDA     gpp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gpp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #ga
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gpp
                LDA     _fcc_fpr0+2
                STA     gpp+2
                SEP     #$20
                MX      %10
                LDA     gpp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gpp
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
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
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                LDA     _fcc_ptr+2
                PHA
                LDA     3,S
                STA     _fcc_ptr
                LDA     5,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                PLA
                LDY     #2
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr],Y
                REP     #$20
                MX      %00
                PLA
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
                LDA     #8
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
                LDA     _fcc_img0
                PHA
                LDA     #1
                ASL
                ASL
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gpp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gpp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
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
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                LDA     #5
                CLC
                ADC     #gbuf
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gs
                LDA     _fcc_fpr0+2
                STA     gs+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gpp
                LDA     _fcc_fpr0+2
                STA     gpp+2
                LDA     #gbuf
                PHA
                LDA     #2
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
                SEP     #$20
                MX      %10
                LDA     gpp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gpp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                SEC
                SBC     #3
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                PHA
                LDA     #0
                TAX
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gs+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gs
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
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
