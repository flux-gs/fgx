                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from walkcopy.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _walkcopy_ccopy
_walkcopy_ccopy            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_walkcopy_ccopy_FRAMESIZE
                DO      _walkcopy_ccopy_STKGUARD
                BCC     _walkcopy_ccopy_stkovf
                CMP     _fcc_stkfloor
                BCS     _walkcopy_ccopy_stkok
_walkcopy_ccopy_stkovf       JMP     _fcc_stkoflow
                FIN
_walkcopy_ccopy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_walkcopy_ccopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_walkcopy_ccopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_walkcopy_ccopy_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      12+_walkcopy_ccopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_walkcopy_ccopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_walkcopy_ccopy_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img1
                DO      6+_walkcopy_ccopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_walkcopy_ccopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_walkcopy_ccopy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+_walkcopy_ccopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_walkcopy_ccopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_walkcopy_ccopy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
_walkcopy_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img0]
                AND     #$00FF
                CMP     #0
                BEQ     _walkcopy_L1
                LDA     [_fcc_img0]
                INC     _fcc_img0
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     [_fcc_img2]
                REP     #$20
                MX      %00
                INC     _fcc_img2
                BRA     _walkcopy_L0
_walkcopy_L1
                LDA     _fcc_img3
                STA     _fcc_fpr0+2
                LDA     _fcc_img2
                STA     _fcc_fpr0
                LDA     #0
                SEP     #$20
                MX      %10
                STA     [_fcc_fpr0]
                REP     #$20
                MX      %00
                TAY
                TSC
                CLC
                ADC     #_walkcopy_ccopy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_walkcopy_ccopy_FRAMESIZE   EQU     0
_walkcopy_ccopy_STKGUARD    EQU     0
                FGX2_EXPORT _walkcopy_icopy
_walkcopy_icopy            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_walkcopy_icopy_FRAMESIZE
                DO      _walkcopy_icopy_STKGUARD
                BCC     _walkcopy_icopy_stkovf
                CMP     _fcc_stkfloor
                BCS     _walkcopy_icopy_stkok
_walkcopy_icopy_stkovf       JMP     _fcc_stkoflow
                FIN
_walkcopy_icopy_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      14+_walkcopy_icopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_walkcopy_icopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_walkcopy_icopy_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_img0
                DO      6+_walkcopy_icopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_walkcopy_icopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_walkcopy_icopy_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+_walkcopy_icopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_walkcopy_icopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_walkcopy_icopy_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                DO      10+_walkcopy_icopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_walkcopy_icopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_walkcopy_icopy_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img3
                DO      12+_walkcopy_icopy_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_walkcopy_icopy_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_walkcopy_icopy_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img4
_walkcopy_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _walkcopy_L4
                EOR     #$8000
_walkcopy_L4
                BPL     _walkcopy_L3
                LDA     [_fcc_img3]
                PHA
                LDA     _fcc_img3
                INC
                INC
                STA     _fcc_img3
                PLA
                STA     [_fcc_img1]
                LDA     _fcc_img1
                INC
                INC
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #1
                STA     _fcc_img0
                BRA     _walkcopy_L2
_walkcopy_L3
                TAY
                TSC
                CLC
                ADC     #_walkcopy_icopy_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_walkcopy_icopy_FRAMESIZE   EQU     0
_walkcopy_icopy_STKGUARD    EQU     0
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
                LDA     #_walkcopy_csrc
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #65
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_walkcopy_csrc
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #66
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_walkcopy_csrc
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_walkcopy_csrc
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
                LDA     #_walkcopy_cdst
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _walkcopy_ccopy
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #_walkcopy_isrc
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #3
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_walkcopy_isrc
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #5
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #2
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_walkcopy_isrc
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
                LDA     #_walkcopy_idst
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _walkcopy_icopy
                TSC
                CLC
                ADC     #10
                TCS
                LDA     #0
                TAX
                LDA:    _walkcopy_cdst,X
                AND     #$00FF
                PHA
                LDA     #1
                TAX
                LDA:    _walkcopy_cdst,X
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #0
                ASL
                TAX
                LDA:    _walkcopy_idst,X
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #1
                ASL
                TAX
                LDA:    _walkcopy_idst,X
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
