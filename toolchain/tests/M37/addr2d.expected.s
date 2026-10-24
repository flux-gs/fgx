                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from addr2d.c
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
                LDA     #rows
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #r0
                STA     _fcc_fpr0
                PLA
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
                LDA     #rows
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #r1
                STA     _fcc_fpr0
                PLA
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rows
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gyy
                LDA     _fcc_fpr0+2
                STA     gyy+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #rows
                STA     _fcc_fpr0
                PLA
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     gw+0
                TAY
                LDA     _fcc_ptr+2
                STA     gw+2
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gw
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_fpr0
                STA     9,S   ; fccstk d=0 b=9
                LDA     #irows
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #i0
                STA     _fcc_fpr0
                PLA
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #irows
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gii
                LDA     _fcc_fpr0+2
                STA     gii+2
                LDA     #1
                STA     _fcc_img1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #81
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gyy+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gyy
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #81
                BEQ     *+5
                BRL     _addr2d_L1
                LDA     #2
                TAX
                LDA:    r1,X
                AND     #$00FF
                TAX
                TXA
                CMP     #81
                BEQ     *+5
                BRL     _addr2d_L1
                LDA     #1
                BRL     _addr2d_L2
_addr2d_L1
                LDA     #0
_addr2d_L2
                CMP     #0
                BNE     *+5
                BRL     _addr2d_L0
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_addr2d_L0
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
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
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                LDA     _fcc_img1
                TAX
                TXA
                INC
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #90
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=0 b=9
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
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
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
                LDA     #2
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _addr2d_L4
                LDA     #2
                TAX
                LDA:    r0,X
                AND     #$00FF
                TAX
                TXA
                CMP     #90
                BEQ     *+5
                BRL     _addr2d_L4
                LDA     #1
                BRL     _addr2d_L5
_addr2d_L4
                LDA     #0
_addr2d_L5
                CMP     #0
                BNE     *+5
                BRL     _addr2d_L3
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_addr2d_L3
                LDA     #0
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gii+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gii
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDA     #4242
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     gii+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     gii
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #2
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                TXA
                CMP     #4242
                BEQ     *+5
                BRL     _addr2d_L9
                LDA     #2
                ASL
                TAX
                LDA:    i0,X
                TAX
                TXA
                CMP     #4242
                BEQ     *+5
                BRL     _addr2d_L9
                LDA     #1
                BRL     _addr2d_L10
_addr2d_L9
                LDA     #0
_addr2d_L10
                CMP     #0
                BNE     *+5
                BRL     _addr2d_L7
                LDA     #1
                ASL
                TAX
                LDA:    i0,X
                TAX
                TXA
                CMP     #0
                BEQ     *+5
                BRL     _addr2d_L7
                LDA     #1
                BRL     _addr2d_L8
_addr2d_L7
                LDA     #0
_addr2d_L8
                CMP     #0
                BNE     *+5
                BRL     _addr2d_L6
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #14
                STA     _fcc_img0
_addr2d_L6
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
