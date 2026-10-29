                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from heapchurn.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #main_FRAMESIZE-8
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #20
                STA     _fcc_img18
                LDA     #0
                STA     _fcc_img19
                LDA     #30
                PHA
                LDA     _fcc_img18
                PHA
                FGX2_FARCALL calloc
                TAY
                PLA
                PLA
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _heapchurn_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _heapchurn_L1
                LDA     #1
                BRA     _heapchurn_L2
_heapchurn_L1
                LDA     #0
_heapchurn_L2
                CMP     #0
                BEQ     _heapchurn_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_heapchurn_L0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     _fcc_img16
_heapchurn_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #46
                BVC     _heapchurn_L6
                EOR     #$8000
_heapchurn_L6
                BMI     *+5
                BRL     _heapchurn_L5
                LDA     _fcc_img16
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_heapchurn_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nbuf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #10
                TCS
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     _fcc_img16
                STA     [_fcc_fpr0]
                LDA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #nbuf
                STA     _fcc_fpr1
                PLA
                PEI     _fcc_fpr1+2
                PEI     _fcc_fpr1
                FGX2_FARCALL strdup
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0
                STA     _fcc_fpr1
                LDA     _fcc_fpr0+2
                STA     _fcc_fpr1+2
                TAY
                PLA
                STA     _fcc_fpr0
                PLA
                STA     _fcc_fpr0+2
                TYA
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _heapchurn_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _heapchurn_L8
                LDA     #1
                BRA     _heapchurn_L9
_heapchurn_L8
                LDA     #0
_heapchurn_L9
                CMP     #0
                BEQ     _heapchurn_L7
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_heapchurn_L7
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #30
                STA     13,S   ; fccstk d=0 b=13
                INC     _fcc_img19
                LDA     _fcc_img19
                TAX
                LDA     _fcc_img18
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _heapchurn_L10
                LDA     _fcc_img18
                ASL
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_fpr0+2
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL realloc
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _heapchurn_L12
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _heapchurn_L12
                LDA     #1
                BRA     _heapchurn_L13
_heapchurn_L12
                LDA     #0
_heapchurn_L13
                CMP     #0
                BEQ     _heapchurn_L11
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_heapchurn_L11
                LDA     _fcc_img18
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_img18
                TAX
                LDA     #2
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                STA     _fcc_img18
_heapchurn_L10
_heapchurn_L4
                INC     _fcc_img16
                BRL     _heapchurn_L3
_heapchurn_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     _fcc_img16
_heapchurn_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #46
                BVC     _heapchurn_L17
                EOR     #$8000
_heapchurn_L17
                BMI     *+5
                BRL     _heapchurn_L16
                LDA     _fcc_img16
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_heapchurn_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #nbuf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sprintf
                TSC
                CLC
                ADC     #10
                TCS
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                LDA     _fcc_img16
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _heapchurn_L18
                LDA     #200
                CLC
                ADC     _fcc_img16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_heapchurn_L18
                LDA     #0
                STA     _fcc_img17
_heapchurn_L19
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                TAX
                LDA:    nbuf,X
                AND     #$00FF
                BEQ     _heapchurn_L21
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img17
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                PHA
                LDA     _fcc_img17
                TAX
                LDA:    nbuf,X
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _heapchurn_L22
                LDA     #100
                CLC
                ADC     _fcc_img16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_heapchurn_L22
_heapchurn_L20
                INC     _fcc_img17
                BRA     _heapchurn_L19
_heapchurn_L21
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                LDA     _fcc_img17
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BEQ     _heapchurn_L23
                LDA     #100
                CLC
                ADC     _fcc_img16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_heapchurn_L23
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #30
                STA     13,S   ; fccstk d=0 b=13
_heapchurn_L15
                INC     _fcc_img16
                BRL     _heapchurn_L14
_heapchurn_L16
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     15,S   ; fccstk d=0 b=15
                LDA     _fcc_fpr0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     _fcc_img16
_heapchurn_L24
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #46
                BVC     _heapchurn_L27
                EOR     #$8000
_heapchurn_L27
                BPL     _heapchurn_L26
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                SEP     #$20
                MX      %10
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL free
                TSC
                CLC
                ADC     #4
                TCS
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
                CLC
                ADC     #30
                STA     13,S   ; fccstk d=0 b=13
_heapchurn_L25
                INC     _fcc_img16
                BRA     _heapchurn_L24
_heapchurn_L26
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL free
                TSC
                CLC
                ADC     #4
                TCS
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
main_bandx
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     24
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 9
