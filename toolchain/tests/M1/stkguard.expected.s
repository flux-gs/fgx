                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from stkguard.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT recurse
recurse            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #recurse_FRAMESIZE
                DO      recurse_STKGUARD
                BCC     recurse_stkovf
                CMP     _fcc_stkfloor
                BCS     recurse_stkok
recurse_stkovf       JMP     _fcc_stkoflow
                FIN
recurse_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                DO      8+recurse_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+recurse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+recurse_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
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
                LDA     sink
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     sink
                DO      6+recurse_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+recurse_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+recurse_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                PHA
                FGX2_FARCALL recurse
                TAY
                PLA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #recurse_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
recurse_FRAMESIZE   EQU     32
recurse_STKGUARD    EQU     1
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
                PHA
                FGX2_FARCALL recurse
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
                FGX2_RELOC_COUNT 5
