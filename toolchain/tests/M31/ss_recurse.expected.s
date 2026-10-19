                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ss_recurse.c
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
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img0
_ss_recurse_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     #256
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ss_recurse_L3
                EOR     #$8000
_ss_recurse_L3
                BMI     *+5
                BRL     _ss_recurse_L2
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #4
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                DO      10+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+rec_FRAMESIZE,S   ; fccstk d=2 b=8 fs
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
_ss_recurse_L1
                INC     _fcc_img0
                BRL     _ss_recurse_L0
_ss_recurse_L2
                LDA     _fcc_img0
                STA     1,S   ; fccstk d=0 b=1
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
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ss_recurse_L5
                EOR     #$8000
_ss_recurse_L5
                BMI     *+5
                BRL     _ss_recurse_L4
                DO      8+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+rec_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                AND     #$00FF
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
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
                TAX
                LDA     #1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                PHA
                FGX2_FARCALL rec
                TAY
                PLA
                PLA
                TYA
                STA     3,S   ; fccstk d=0 b=3
                BRL     _ss_recurse_L6
_ss_recurse_L4
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
_ss_recurse_L6
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
                PHA
                DO      10+rec_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+rec_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+rec_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _ss_recurse_L7
                LDA     #100
                TAY
                TSC
                CLC
                ADC     #rec_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ss_recurse_L7
                LDA     3,S   ; fccstk d=0 b=3
                PHA
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
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #rec_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
rec_FRAMESIZE   EQU     260
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
                LDA     #9
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL rec
                TAY
                PLA
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
