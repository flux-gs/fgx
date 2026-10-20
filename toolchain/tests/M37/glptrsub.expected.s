                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from glptrsub.c
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
_glptrsub_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #8
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _glptrsub_L3
                EOR     #$8000
_glptrsub_L3
                BMI     *+5
                BRL     _glptrsub_L2
                LDA     #larr
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
_glptrsub_L1
                INC     _fcc_img0
                BRL     _glptrsub_L0
_glptrsub_L2
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #larr
                STA     _fcc_fpr0
                STA     lp
                LDA     _fcc_fpr0+2
                STA     lp+2
                SEP     #$20
                MX      %10
                LDA     lp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     lp
                PHA
                LDA     #3
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                SEP     #$20
                MX      %10
                LDA     lp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     lp
                PHA
                LDA     #7
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                LDA     #3
                ASL
                ASL
                TAX
                LDA:    larr+2,X
                STA     _fcc_long_hi
                LDA:    larr,X
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _glptrsub_L4
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
_glptrsub_L4
                LDA     #7
                ASL
                ASL
                TAX
                LDA:    larr+2,X
                STA     _fcc_long_hi
                LDA:    larr,X
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _glptrsub_L5
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
_glptrsub_L5
                LDA     #larr
                PHA
                LDA     #5
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$002A
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
                LDA     #5
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     lp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     lp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$002A
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _glptrsub_L6
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
_glptrsub_L6
                LDA     #3
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     lp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     lp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0064
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _glptrsub_L7
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
_glptrsub_L7
                LDA     #7
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     lp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     lp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$3039
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _glptrsub_L8
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
_glptrsub_L8
                LDA     #5
                ASL
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     lp+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     lp
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
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
