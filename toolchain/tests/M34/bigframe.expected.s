                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from bigframe.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT bigfield
bigfield            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bigfield_FRAMESIZE
                DO      bigfield_STKGUARD
                BCC     bigfield_stkovf
                CMP     _fcc_stkfloor
                BCS     bigfield_stkok
bigfield_stkovf       JMP     _fcc_stkoflow
                FIN
bigfield_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                LDA     #20
                PHA
                TSC
                CLC
                ADC     #305
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                TSC
                CLC
                ADC     #305
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #bigfield_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bigfield_FRAMESIZE   EQU     304
bigfield_STKGUARD    EQU     1
                FGX2_EXPORT bigelem
bigelem            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #bigelem_FRAMESIZE
                DO      bigelem_STKGUARD
                BCC     bigelem_stkovf
                CMP     _fcc_stkfloor
                BCS     bigelem_stkok
bigelem_stkovf       JMP     _fcc_stkoflow
                FIN
bigelem_stkok        TCS
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
                LDA     #280
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #15
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
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #3
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
                LDA     #280
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
                ADC     #0
                PHA
                LDA     #2
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
                ADC     #bigelem_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
bigelem_FRAMESIZE   EQU     300
bigelem_STKGUARD    EQU     1
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
                LDA     args_argc
                DO      6+main_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+main_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     #0
                SEP     #$20
                MX      %10
                PHB
                PLA
                REP     #$20
                MX      %00
                DO      10+main_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #12+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     10+main_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                LDA     #args_argv
                DO      8+main_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #10+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     8+main_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #299
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #2
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
                FGX2_FARCALL bigfield
                PHA
                FGX2_FARCALL bigelem
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                DO      8+main_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+main_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+main_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                TAX
                TXA
                SEC
                SBC     #1
                BVC     _bigframe_L2
                EOR     #$8000
_bigframe_L2
                BPL     *+5
                BRL     _bigframe_L0
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
                LDA     #299
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                BRL     _bigframe_L1
_bigframe_L0
                LDA     #0
_bigframe_L1
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     300
main_STKGUARD    EQU     1
                FGX2_RELOC_COUNT 6
