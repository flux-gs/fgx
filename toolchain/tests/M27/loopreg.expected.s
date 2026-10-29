                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from loopreg.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _loopreg_helper
_loopreg_helper            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_loopreg_helper_FRAMESIZE
                DO      _loopreg_helper_STKGUARD
                BCC     _loopreg_helper_stkovf
                CMP     _fcc_stkfloor
                BCS     _loopreg_helper_stkok
_loopreg_helper_stkovf       JMP     _fcc_stkoflow
                FIN
_loopreg_helper_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_loopreg_helper_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_loopreg_helper_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_loopreg_helper_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAX
                INC
                TAY
                TSC
                CLC
                ADC     #_loopreg_helper_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_loopreg_helper_FRAMESIZE   EQU     0
_loopreg_helper_STKGUARD    EQU     0
                FGX2_EXPORT _loopreg_sum_loop
_loopreg_sum_loop            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #_loopreg_sum_loop_FRAMESIZE-4
                DO      _loopreg_sum_loop_STKGUARD
                BCC     _loopreg_sum_loop_stkovf
                CMP     _fcc_stkfloor
                BCS     _loopreg_sum_loop_stkok
_loopreg_sum_loop_stkovf       JMP     _fcc_stkoflow
                FIN
_loopreg_sum_loop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img17
                PHA
                FGX2_FARCALL _loopreg_helper
                TAY
                PLA
                TYA
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
                DO      6+_loopreg_sum_loop_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_loopreg_sum_loop_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_loopreg_sum_loop_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
_loopreg_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _loopreg_L3
                EOR     #$8000
_loopreg_L3
                BPL     _loopreg_L2
                LDA     _fcc_img17
                CLC
                ADC     _fcc_img16
                STA     _fcc_img17
_loopreg_L1
                INC     _fcc_img16
                BRA     _loopreg_L0
_loopreg_L2
                LDA     _fcc_img0
                DO      6+_loopreg_sum_loop_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+_loopreg_sum_loop_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+_loopreg_sum_loop_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_img17
                TAY
                TSC
                CLC
                ADC     #_loopreg_sum_loop_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_loopreg_sum_loop_FRAMESIZE   EQU     8
_loopreg_sum_loop_STKGUARD    EQU     0
                FGX2_EXPORT _loopreg_with_break
_loopreg_with_break            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #_loopreg_with_break_FRAMESIZE-4
                DO      _loopreg_with_break_STKGUARD
                BCC     _loopreg_with_break_stkovf
                CMP     _fcc_stkfloor
                BCS     _loopreg_with_break_stkok
_loopreg_with_break_stkovf       JMP     _fcc_stkoflow
                FIN
_loopreg_with_break_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img17
                PHA
                FGX2_FARCALL _loopreg_helper
                TAY
                PLA
                TYA
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
                DO      6+_loopreg_with_break_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_loopreg_with_break_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_loopreg_with_break_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
_loopreg_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _loopreg_L7
                EOR     #$8000
_loopreg_L7
                BPL     _loopreg_L6
                LDA     _fcc_img16
                TAX
                CMP     #3
                BNE     _loopreg_L8
                BRA     _loopreg_L6
_loopreg_L8
                LDA     _fcc_img17
                CLC
                ADC     _fcc_img16
                STA     _fcc_img17
_loopreg_L5
                INC     _fcc_img16
                BRA     _loopreg_L4
_loopreg_L6
                LDA     _fcc_img0
                DO      6+_loopreg_with_break_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+_loopreg_with_break_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+_loopreg_with_break_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_img17
                TAY
                TSC
                CLC
                ADC     #_loopreg_with_break_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_loopreg_with_break_FRAMESIZE   EQU     8
_loopreg_with_break_STKGUARD    EQU     0
                FGX2_EXPORT _loopreg_with_cont
_loopreg_with_cont            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #_loopreg_with_cont_FRAMESIZE-4
                DO      _loopreg_with_cont_STKGUARD
                BCC     _loopreg_with_cont_stkovf
                CMP     _fcc_stkfloor
                BCS     _loopreg_with_cont_stkok
_loopreg_with_cont_stkovf       JMP     _fcc_stkoflow
                FIN
_loopreg_with_cont_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img17
                PHA
                FGX2_FARCALL _loopreg_helper
                TAY
                PLA
                TYA
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
                DO      6+_loopreg_with_cont_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_loopreg_with_cont_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_loopreg_with_cont_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img0
_loopreg_L9
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _loopreg_L12
                EOR     #$8000
_loopreg_L12
                BPL     _loopreg_L11
                LDA     _fcc_img16
                TAX
                CMP     #2
                BNE     _loopreg_L13
                BRA     _loopreg_L10
_loopreg_L13
                LDA     _fcc_img17
                CLC
                ADC     _fcc_img16
                STA     _fcc_img17
_loopreg_L10
                INC     _fcc_img16
                BRA     _loopreg_L9
_loopreg_L11
                LDA     _fcc_img0
                DO      6+_loopreg_with_cont_FRAMESIZE/256
                PHA
                TSC
                CLC
                ADC     #8+_loopreg_with_cont_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                PLA
                STA     [_fcc_fp]
                ELSE
                STA     6+_loopreg_with_cont_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                LDA     _fcc_img17
                TAY
                TSC
                CLC
                ADC     #_loopreg_with_cont_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_loopreg_with_cont_FRAMESIZE   EQU     8
_loopreg_with_cont_STKGUARD    EQU     0
                FGX2_EXPORT _loopreg_with_goto
_loopreg_with_goto            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #_loopreg_with_goto_FRAMESIZE-4
                DO      _loopreg_with_goto_STKGUARD
                BCC     _loopreg_with_goto_stkovf
                CMP     _fcc_stkfloor
                BCS     _loopreg_with_goto_stkok
_loopreg_with_goto_stkovf       JMP     _fcc_stkoflow
                FIN
_loopreg_with_goto_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img17
                PHA
                FGX2_FARCALL _loopreg_helper
                TAY
                PLA
                TYA
                STA     _fcc_img17
                LDA     #0
                STA     _fcc_img16
_loopreg_L14
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                DO      6+_loopreg_with_goto_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_loopreg_with_goto_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_loopreg_with_goto_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _loopreg_L17
                EOR     #$8000
_loopreg_L17
                BPL     _loopreg_L16
                LDA     _fcc_img17
                CLC
                ADC     _fcc_img16
                STA     _fcc_img17
                LDA     _fcc_img16
                TAX
                CMP     #2
                BNE     _loopreg_L18
                BRA     _loopreg_with_goto_uL_done
_loopreg_L18
_loopreg_L15
                INC     _fcc_img16
                BRA     _loopreg_L14
_loopreg_L16
_loopreg_with_goto_uL_done
                LDA     _fcc_img17
                TAY
                TSC
                CLC
                ADC     #_loopreg_with_goto_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
_loopreg_with_goto_FRAMESIZE   EQU     8
_loopreg_with_goto_STKGUARD    EQU     0
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
                FGX2_FARCALL _loopreg_helper
                TAY
                PLA
                TYA
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #5
                PHA
                FGX2_FARCALL _loopreg_sum_loop
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #10
                PHA
                FGX2_FARCALL _loopreg_with_break
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #5
                PHA
                FGX2_FARCALL _loopreg_with_cont
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #5
                PHA
                FGX2_FARCALL _loopreg_with_goto
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     1,S   ; fccstk d=0 b=1
                TAX
                AND     #255
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
                FGX2_RELOC_COUNT 16
