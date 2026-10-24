                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from stkfloor.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT rec
rec            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #rec_FRAMESIZE
                DO      rec_STKGUARD
                BCC     rec_stkovf
                CMP     _fcc_stkfloor
                BCS     rec_stkok
rec_stkovf       JMP     _fcc_stkoflow
                FIN
rec_stkok        TCS
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
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                DO      8+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+rec_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
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
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #7
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                DO      8+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+rec_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
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
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
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
                LDA     #7
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     sink
                DO      6+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+rec_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                LDX     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _stkfloor_L1
                EOR     #$8000
_stkfloor_L1
                BPL     _stkfloor_L0
                DO      6+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+rec_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                SEC
                SBC     #1
                PHA
                FGX2_FARCALL rec
                TAY
                PLA
                TYA
_stkfloor_L0
                TAY
                TSC
                CLC
                ADC     #rec_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
rec_FRAMESIZE   EQU     16
rec_STKGUARD    EQU     1
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
                LDA     depth
                PHA
                FGX2_FARCALL rec
                TAY
                PLA
                TYA
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
                FGX2_RELOC_COUNT 5
