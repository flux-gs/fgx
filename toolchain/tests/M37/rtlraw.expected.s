                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from rtlraw.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT vsum2
vsum2            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #vsum2_FRAMESIZE
                DO      vsum2_STKGUARD
                BCC     vsum2_stkovf
                CMP     _fcc_stkfloor
                BCS     vsum2_stkok
vsum2_stkovf       JMP     _fcc_stkoflow
                FIN
vsum2_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+vsum2_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #2
                TAX
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
_rtlraw_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                DO      6+vsum2_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+vsum2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+vsum2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                DEC
                DO      6+vsum2_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+vsum2_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+vsum2_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_tmp_b
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _rtlraw_L2
                EOR     #$8000
_rtlraw_L2
                BPL     _rtlraw_L1
                LDA     _fcc_img0
                PHA
                LDA     _fcc_img2
                STA     _fcc_fpr0+2
                LDA     _fcc_img1
                STA     _fcc_fpr0
                LDA     #2
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     #2
                TAX
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                BRL     _rtlraw_L0
_rtlraw_L1
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     _fcc_fpr0+2
                STA     _fcc_img2
                LDA     _fcc_fpr0
                STA     _fcc_img1
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #vsum2_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
vsum2_FRAMESIZE   EQU     6
vsum2_STKGUARD    EQU     0
                FGX2_EXPORT probe
probe            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #probe_FRAMESIZE
                DO      probe_STKGUARD
                BCC     probe_stkovf
                CMP     _fcc_stkfloor
                BCS     probe_stkok
probe_stkovf       JMP     _fcc_stkoflow
                FIN
probe_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #7
                STA     1,S   ; fccstk d=0 b=1
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     #0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #4
                STA     7,S   ; fccstk d=0 b=7
                DO      16+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+probe_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     _fcc_ptr+2
                DO      14+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+probe_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                PHA
                DO      14+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+probe_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                PHA
                LDA     7,S   ; fccstk d=6 b=1
                PHA
                DO      16+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+probe_FRAMESIZE,S   ; fccstk d=8 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      14+probe_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+probe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+probe_FRAMESIZE,S   ; fccstk d=8 b=6 fs
                FIN
                PHA
                LDA     #5
                PHA
                FGX2_FARCALL vsum2
                TAY
                PLA
                PLA
                PLA
                PLA
                PLA
                PLA
                TYA
                TAY
                TSC
                CLC
                ADC     #probe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
probe_FRAMESIZE   EQU     8
probe_STKGUARD    EQU     0
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
                LDA     #5
                STA     5,S   ; fccstk d=0 b=5
                LDA     #11
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                TSC
                SEC
                SBC     #4
                TCS
                TSC
                INC
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDY     #2
_rtlraw_L3
                LDA     [_fcc_fpr0],Y
                STA     [_fcc_fpr1],Y
                DEY
                DEY
                BPL     _rtlraw_L3
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$000C
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL probe
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                TAX
                CLC
                ADC     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
