                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from knr_strconcat.c
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_knr_strconcat_S0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img4
                LDA     _fcc_fpr0
                STA     _fcc_img3
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_knr_strconcat_S1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img6
                LDA     _fcc_fpr0
                STA     _fcc_img5
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_knr_strconcat_S2
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img8
                LDA     _fcc_fpr0
                STA     _fcc_img7
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_knr_strconcat_S3
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #100
                BEQ     _knr_strconcat_L0
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #1
                STA     _fcc_img0
_knr_strconcat_L0
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     #6
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BEQ     _knr_strconcat_L1
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #2
                STA     _fcc_img0
_knr_strconcat_L1
                LDA     _fcc_img6
                STA     _fcc_ptr+2
                LDA     _fcc_img5
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #33
                BEQ     _knr_strconcat_L2
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #4
                STA     _fcc_img0
_knr_strconcat_L2
                LDA     _fcc_img8
                STA     _fcc_ptr+2
                LDA     _fcc_img7
                PHA
                LDA     #3
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #100
                BEQ     _knr_strconcat_L3
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #8
                STA     _fcc_img0
_knr_strconcat_L3
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #1
                BEQ     _knr_strconcat_L4
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #16
                STA     _fcc_img0
_knr_strconcat_L4
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #50
                BEQ     _knr_strconcat_L5
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #32
                STA     _fcc_img0
_knr_strconcat_L5
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BEQ     _knr_strconcat_L6
                LDA     _fcc_img0
                TAX
                CLC
                ADC     #64
                STA     _fcc_img0
_knr_strconcat_L6
                LDA     _fcc_img0
                BEQ     _knr_strconcat_L7
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
_knr_strconcat_L7
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
