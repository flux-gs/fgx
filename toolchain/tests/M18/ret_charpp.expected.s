                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ret_charpp.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fill
fill            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fill_FRAMESIZE
                DO      fill_STKGUARD
                BCC     fill_stkovf
                CMP     _fcc_stkfloor
                BCS     fill_stkok
fill_stkovf       JMP     _fcc_stkoflow
                FIN
fill_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #tab
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
                DO      10+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+fill_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fill_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
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
                LDA     #tab
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
                DO      14+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+fill_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+fill_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+fill_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+fill_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
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
                LDA     #tab
                STA     _fcc_fpr0
                PLA
                TAY
                TSC
                CLC
                ADC     #fill_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fill_FRAMESIZE   EQU     0
fill_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ret_charpp_S1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ret_charpp_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fill
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
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
                PHA
                LDA     _fcc_img17
                STA     _fcc_ptr+2
                LDA     _fcc_img16
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDY     #2
                LDA     [_fcc_ptr],Y
                AND     #$00FF
                STA     _fcc_fpr0+2
                LDA     [_fcc_ptr]
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
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
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
