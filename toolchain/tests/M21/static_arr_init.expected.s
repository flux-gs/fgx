                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_arr_init.c
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
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    main_sl_names+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    main_sl_names,X
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #97
                BNE     *+5
                BRL     _static_arr_init_L0
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
_static_arr_init_L0
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    main_sl_names+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    main_sl_names,X
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #98
                BNE     *+5
                BRL     _static_arr_init_L1
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
_static_arr_init_L1
                LDA     #2
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    main_sl_names+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    main_sl_names,X
                STA     _fcc_fpr0
                LDA     #0
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                TAX
                TXA
                CMP     #99
                BNE     *+5
                BRL     _static_arr_init_L2
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
_static_arr_init_L2
                LDA     #0
                TAX
                LDA:    main_sl_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #120
                BNE     *+5
                BRL     _static_arr_init_L3
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
_static_arr_init_L3
                LDA     #2
                TAX
                LDA:    main_sl_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #122
                BNE     *+5
                BRL     _static_arr_init_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_static_arr_init_L4
                LDA     #3
                TAX
                LDA:    main_sl_buf,X
                AND     #$00FF
                TAX
                TXA
                CMP     #0
                BNE     *+5
                BRL     _static_arr_init_L5
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_static_arr_init_L5
                LDA     #0
                ASL
                TAX
                LDA:    main_sl_nums,X
                TAX
                TXA
                CMP     #10
                BNE     *+5
                BRL     _static_arr_init_L6
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_static_arr_init_L6
                LDA     #3
                ASL
                TAX
                LDA:    main_sl_nums,X
                CMP     #$FFFF
                BNE     *+5
                BRL     _static_arr_init_L7
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_static_arr_init_L7
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
