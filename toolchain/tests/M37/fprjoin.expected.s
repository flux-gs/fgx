                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fprjoin.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pick
pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pick_FRAMESIZE
                DO      pick_STKGUARD
                BCC     pick_stkovf
                CMP     _fcc_stkfloor
                BCS     pick_stkok
pick_stkovf       JMP     _fcc_stkoflow
                FIN
pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #0
                BEQ     _fprjoin_L2
                DO      10+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+pick_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                BRA     _fprjoin_L3
_fprjoin_L2
                DO      14+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+pick_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+pick_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
_fprjoin_L3
                TAX
                CMP     #99
                BNE     _fprjoin_L0
                LDA     #0
                BRA     _fprjoin_L1
_fprjoin_L0
                DO      10+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+pick_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
_fprjoin_L1
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pick_FRAMESIZE   EQU     0
pick_STKGUARD    EQU     0
                FGX2_EXPORT walk
walk            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #walk_FRAMESIZE
                DO      walk_STKGUARD
                BCC     walk_stkovf
                CMP     _fcc_stkfloor
                BCS     walk_stkok
walk_stkovf       JMP     _fcc_stkoflow
                FIN
walk_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+walk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+walk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                SEC
                SBC     #1
                STA     _fcc_img0
walk_uL_top
                LDA     _fcc_img0
                PHA
                DO      10+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+walk_FRAMESIZE,S   ; fccstk d=2 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      8+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+walk_FRAMESIZE,S   ; fccstk d=2 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                DO      8+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+walk_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+walk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CLC
                ADC     #4
                DO      6+walk_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+walk_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                DO      10+walk_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+walk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                DEC
                DO      10+walk_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #12+walk_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     10+walk_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                CMP     #0
                BEQ     _fprjoin_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                BRA     walk_uL_top
_fprjoin_L4
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #walk_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
walk_FRAMESIZE   EQU     2
walk_STKGUARD    EQU     0
                FGX2_EXPORT sel
sel            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #sel_FRAMESIZE
                DO      sel_STKGUARD
                BCC     sel_stkovf
                CMP     _fcc_stkfloor
                BCS     sel_stkok
sel_stkovf       JMP     _fcc_stkoflow
                FIN
sel_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sel_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sel_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #1
                BNE     _fprjoin_L5
                DO      12+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sel_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      10+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+sel_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #10
                BNE     _fprjoin_L5
                DO      8+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+sel_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+sel_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                DO      14+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+sel_FRAMESIZE,S   ; fccstk d=2 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      12+sel_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+sel_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+sel_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #sel_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fprjoin_L5
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #sel_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
sel_FRAMESIZE   EQU     0
sel_STKGUARD    EQU     0
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
                STA     1,S   ; fccstk d=0 b=1
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x+4
                STA     _fcc_fpr0
                PLA
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
                LDA     #x
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #1
                PHA
                FGX2_FARCALL pick
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                CMP     #2
                BNE     _fprjoin_L6
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_fprjoin_L6
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x+4
                STA     _fcc_fpr0
                PLA
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
                LDA     #x
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #0
                PHA
                FGX2_FARCALL pick
                TAY
                TSC
                CLC
                ADC     #10
                TCS
                TYA
                TAX
                CMP     #2
                BNE     _fprjoin_L7
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_fprjoin_L7
                LDA     #3
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL walk
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #111
                BNE     _fprjoin_L8
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #10
                STA     1,S   ; fccstk d=0 b=1
_fprjoin_L8
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x+4
                STA     _fcc_fpr0
                PLA
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
                LDA     #x
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sel
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                TAX
                CMP     #22
                BNE     _fprjoin_L9
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #x+4
                STA     _fcc_fpr0
                PLA
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
                LDA     #x+4
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL sel
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BNE     _fprjoin_L9
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                CLC
                ADC     #12
                STA     1,S   ; fccstk d=0 b=1
_fprjoin_L9
                LDA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 10
