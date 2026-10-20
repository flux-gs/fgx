                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ppstride.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT fknr
fknr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fknr_FRAMESIZE
                DO      fknr_STKGUARD
                BCC     fknr_stkovf
                CMP     _fcc_stkfloor
                BCS     fknr_stkok
fknr_stkovf       JMP     _fcc_stkoflow
                FIN
fknr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+fknr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fknr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fknr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+fknr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fknr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fknr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                DO      10+fknr_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+fknr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+fknr_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #fknr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fknr_FRAMESIZE   EQU     4
fknr_STKGUARD    EQU     0
                FGX2_EXPORT fansi
fansi            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #fansi_FRAMESIZE
                DO      fansi_STKGUARD
                BCC     fansi_stkovf
                CMP     _fcc_stkfloor
                BCS     fansi_stkok
fansi_stkovf       JMP     _fcc_stkoflow
                FIN
fansi_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+fansi_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+fansi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+fansi_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_ptr
                DO      8+fansi_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+fansi_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+fansi_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAY
                TSC
                CLC
                ADC     #fansi_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
fansi_FRAMESIZE   EQU     4
fansi_STKGUARD    EQU     0
                FGX2_EXPORT floc
floc            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #floc_FRAMESIZE
                DO      floc_STKGUARD
                BCC     floc_stkovf
                CMP     _fcc_stkfloor
                BCS     floc_stkok
floc_stkovf       JMP     _fcc_stkoflow
                FIN
floc_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                STA     _fcc_ptr
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                PHA
                SEP     #$20
                MX      %10
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                PLA
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_fpr1
                LDX     #28
                STX     _fcc_tmp_b
                JSR     _fcc_divs16
                TAY
                TSC
                CLC
                ADC     #floc_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
floc_FRAMESIZE   EQU     8
floc_STKGUARD    EQU     0
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
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     #2
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #9
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #arr
                STA     _fcc_fpr0
                LDA     #3
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     #30
                STA     [_fcc_fpr0]
                LDA     #3
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fknr
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                LDA     #30
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _ppstride_L0
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
_ppstride_L0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL fansi
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAX
                LDA     #9
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _ppstride_L1
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
_ppstride_L1
                FGX2_FARCALL floc
                TAX
                LDA     #3
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _ppstride_L2
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
_ppstride_L2
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
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
