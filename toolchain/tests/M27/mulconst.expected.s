                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from mulconst.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _mulconst_times
_mulconst_times            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_mulconst_times_FRAMESIZE
                DO      _mulconst_times_STKGUARD
                BCC     _mulconst_times_stkovf
                CMP     _fcc_stkfloor
                BCS     _mulconst_times_stkok
_mulconst_times_stkovf       JMP     _fcc_stkoflow
                FIN
_mulconst_times_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_mulconst_times_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mulconst_times_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mulconst_times_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                TAX
                DO      6+_mulconst_times_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mulconst_times_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mulconst_times_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAX
                DO      6+_mulconst_times_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mulconst_times_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mulconst_times_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_mulconst_times_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mulconst_times_FRAMESIZE   EQU     0
_mulconst_times_STKGUARD    EQU     0
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
                LDA     #0
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
_mulconst_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #5
                BVC     _mulconst_L3
                EOR     #$8000
_mulconst_L3
                BPL     _mulconst_L2
                LDA     _fcc_img16
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #_mulconst_tbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_img16
                TAX
                CLC
                ADC     #1
                LDY     #10
                STA     [_fcc_fpr0],Y
_mulconst_L1
                INC     _fcc_img16
                BRA     _mulconst_L0
_mulconst_L2
                LDA     #0
                STA     _fcc_img16
_mulconst_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #5
                BVC     _mulconst_L7
                EOR     #$8000
_mulconst_L7
                BPL     _mulconst_L6
                LDA     _fcc_img17
                PHA
                LDA     _fcc_img16
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #_mulconst_tbl
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #10
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img17
_mulconst_L5
                INC     _fcc_img16
                BRA     _mulconst_L4
_mulconst_L6
                LDA     _fcc_img17
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL _mulconst_times
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #9
                ASL
                ASL
                ASL
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                AND     #255
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
