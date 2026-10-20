                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from global_ptr_init.c
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
                LDA     p+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     p
                PHA
                LDA     #0
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
                LDA     #30
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     p
                PHA
                LDA     #1
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
                LDA     #11
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                SEP     #$20
                MX      %10
                LDA     q+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     q
                STA     _fcc_fpr0
                LDA     #7
                STA     [_fcc_fpr0]
                LDA     #0
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     p
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                PHA
                LDA     #1
                ASL
                TAX
                TXA
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     p+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     p
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                SEP     #$20
                MX      %10
                LDA     q+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     q
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                CLC
                ADC     second
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
