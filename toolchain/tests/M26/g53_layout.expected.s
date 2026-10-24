                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from g53_layout.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT layout
layout            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #layout_FRAMESIZE
                DO      layout_STKGUARD
                BCC     layout_stkovf
                CMP     _fcc_stkfloor
                BCS     layout_stkok
layout_stkovf       JMP     _fcc_stkoflow
                FIN
layout_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+layout_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+layout_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+layout_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_img0
_g53_layout_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #300
                BVC     _g53_layout_L3
                EOR     #$8000
_g53_layout_L3
                BPL     _g53_layout_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img0
                TAX
                AND     #127
                AND     #$00FF
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
_g53_layout_L1
                INC     _fcc_img0
                BRA     _g53_layout_L0
_g53_layout_L2
                LDA     #0
                STA     _fcc_img0
_g53_layout_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #100
                BVC     _g53_layout_L7
                EOR     #$8000
_g53_layout_L7
                BPL     _g53_layout_L6
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #320
                STA     _fcc_fpr0
                LDA     _fcc_img0
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_img0
                STA     [_fcc_fpr0]
_g53_layout_L5
                INC     _fcc_img0
                BRA     _g53_layout_L4
_g53_layout_L6
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img3
                LDA     _fcc_fpr0
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img6
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img7
                TYA
                LDA     #0
                STA     _fcc_img1
_g53_layout_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img1
                TAX
                SEC
                SBC     #130
                BVC     _g53_layout_L11
                EOR     #$8000
_g53_layout_L11
                BPL     _g53_layout_L10
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #520
                PHA
                LDA     _fcc_img1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img1
                TAY
                LDA     1,S
                STA     _fcc_ptr
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TYA
                STA     [_fcc_ptr]
                PLA
_g53_layout_L9
                INC     _fcc_img1
                BRA     _g53_layout_L8
_g53_layout_L10
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #520
                PHA
                LDA     #129
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #320
                CLC
                ADC     #198
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_img6
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     _fcc_img7
                TYA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                INC
                INC
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img5
                LDA     _fcc_fpr0
                STA     _fcc_img4
                LDA     _fcc_img5
                STA     _fcc_fpr0+2
                LDA     _fcc_img4
                STA     _fcc_fpr0
                LDA     _fcc_img3
                STA     _fcc_ptr+2
                LDA     _fcc_img2
                PHA
                LDA     #50
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #20
                PHA
                LDA     #140
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                AND     #127
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                STA     [_fcc_fpr0]
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     _fcc_img7
                STA     _fcc_long_hi
                LDA     _fcc_img6
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                SEC
                SBC     #30
                CLC
                ADC     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #layout_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
layout_FRAMESIZE   EQU     780
layout_STKGUARD    EQU     1
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
                LDA     #4
                PHA
                FGX2_FARCALL layout
                TAY
                PLA
                TYA
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
                FGX2_RELOC_COUNT 4
