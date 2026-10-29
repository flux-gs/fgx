                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from popen.c
;---------------------------------------

                MX      %00
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
                LDA     #_popen_S1
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
                LDA     #_popen_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL popen
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _popen_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _popen_L1
                LDA     #1
                BRA     _popen_L2
_popen_L1
                LDA     #0
_popen_L2
                CMP     #0
                BEQ     _popen_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_popen_L0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #16
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgets
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _popen_L4
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _popen_L4
                LDA     #1
                BRA     _popen_L5
_popen_L4
                LDA     #0
_popen_L5
                CMP     #0
                BEQ     _popen_L3
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_popen_L3
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #104
                BNE     _popen_L7
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #105
                BNE     _popen_L7
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     #2
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #10
                BEQ     _popen_L6
_popen_L7
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_popen_L6
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                LDA     #16
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fgets
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _popen_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _popen_L9
                LDA     #0
                BRA     _popen_L10
_popen_L9
                LDA     #1
_popen_L10
                CMP     #0
                BEQ     _popen_L8
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_popen_L8
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL pclose
                PLY
                PLY
                CMP     #0
                BEQ     _popen_L11
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_popen_L11
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_popen_S3
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
                LDA     #_popen_S2
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL popen
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _popen_L13
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _popen_L13
                LDA     #1
                BRA     _popen_L14
_popen_L13
                LDA     #0
_popen_L14
                CMP     #0
                BEQ     _popen_L12
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_popen_L12
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_popen_S4
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fputs
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL pclose
                PLY
                PLY
                CMP     #0
                BEQ     _popen_L15
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_popen_L15
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_popen_S1
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
                LDA     #_popen_S5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL popen
                PLY
                PLY
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _popen_L17
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _popen_L17
                LDA     #1
                BRA     _popen_L18
_popen_L17
                LDA     #0
_popen_L18
                CMP     #0
                BEQ     _popen_L16
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_popen_L16
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL pclose
                PLY
                PLY
                PHA
                LDA     #3
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _popen_L19
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_popen_L19
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_iob
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL pclose
                PLY
                PLY
                CMP     #$FFFF
                BEQ     _popen_L20
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_popen_L20
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
main_bandx
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
                FGX2_RELOC_COUNT 12
