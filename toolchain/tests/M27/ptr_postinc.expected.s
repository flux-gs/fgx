                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_postinc.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ptr_postinc_sum_fwd
_ptr_postinc_sum_fwd            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ptr_postinc_sum_fwd_FRAMESIZE
                DO      _ptr_postinc_sum_fwd_STKGUARD
                BCC     _ptr_postinc_sum_fwd_stkovf
                CMP     _fcc_stkfloor
                BCS     _ptr_postinc_sum_fwd_stkok
_ptr_postinc_sum_fwd_stkovf       JMP     _fcc_stkoflow
                FIN
_ptr_postinc_sum_fwd_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_ptr_postinc_sum_fwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ptr_postinc_sum_fwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ptr_postinc_sum_fwd_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+_ptr_postinc_sum_fwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ptr_postinc_sum_fwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ptr_postinc_sum_fwd_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img0
_ptr_postinc_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img2]
                INC     _fcc_img2
                AND     #$00FF
                STA     _fcc_img1
                BEQ     _ptr_postinc_L1
                LDA     _fcc_img0
                CLC
                ADC     _fcc_img1
                STA     _fcc_img0
                BRA     _ptr_postinc_L0
_ptr_postinc_L1
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #_ptr_postinc_sum_fwd_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_postinc_sum_fwd_FRAMESIZE   EQU     4
_ptr_postinc_sum_fwd_STKGUARD    EQU     0
                FGX2_EXPORT _ptr_postinc_sum_bwd
_ptr_postinc_sum_bwd            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ptr_postinc_sum_bwd_FRAMESIZE
                DO      _ptr_postinc_sum_bwd_STKGUARD
                BCC     _ptr_postinc_sum_bwd_stkovf
                CMP     _fcc_stkfloor
                BCS     _ptr_postinc_sum_bwd_stkok
_ptr_postinc_sum_bwd_stkovf       JMP     _fcc_stkoflow
                FIN
_ptr_postinc_sum_bwd_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_ptr_postinc_sum_bwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ptr_postinc_sum_bwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ptr_postinc_sum_bwd_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      6+_ptr_postinc_sum_bwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ptr_postinc_sum_bwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ptr_postinc_sum_bwd_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+_ptr_postinc_sum_bwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ptr_postinc_sum_bwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ptr_postinc_sum_bwd_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img1
_ptr_postinc_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptr_postinc_L4
                EOR     #$8000
_ptr_postinc_L4
                BPL     _ptr_postinc_L3
                LDA     _fcc_img1
                PHA
                LDA     [_fcc_img2]
                DEC     _fcc_img2
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #1
                STA     _fcc_img0
                BRA     _ptr_postinc_L2
_ptr_postinc_L3
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_ptr_postinc_sum_bwd_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_postinc_sum_bwd_FRAMESIZE   EQU     2
_ptr_postinc_sum_bwd_STKGUARD    EQU     0
                FGX2_EXPORT _ptr_postinc_isum_bwd
_ptr_postinc_isum_bwd            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ptr_postinc_isum_bwd_FRAMESIZE
                DO      _ptr_postinc_isum_bwd_STKGUARD
                BCC     _ptr_postinc_isum_bwd_stkovf
                CMP     _fcc_stkfloor
                BCS     _ptr_postinc_isum_bwd_stkok
_ptr_postinc_isum_bwd_stkovf       JMP     _fcc_stkoflow
                FIN
_ptr_postinc_isum_bwd_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_ptr_postinc_isum_bwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ptr_postinc_isum_bwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ptr_postinc_isum_bwd_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img0
                DO      6+_ptr_postinc_isum_bwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ptr_postinc_isum_bwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ptr_postinc_isum_bwd_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+_ptr_postinc_isum_bwd_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ptr_postinc_isum_bwd_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ptr_postinc_isum_bwd_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                LDA     #0
                STA     _fcc_img1
_ptr_postinc_L5
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                LDX     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptr_postinc_L7
                EOR     #$8000
_ptr_postinc_L7
                BPL     _ptr_postinc_L6
                LDA     _fcc_img1
                PHA
                LDA     [_fcc_img2]
                PHA
                LDA     _fcc_img2
                DEC
                DEC
                STA     _fcc_img2
                PLA
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #1
                STA     _fcc_img0
                BRA     _ptr_postinc_L5
_ptr_postinc_L6
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_ptr_postinc_isum_bwd_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_postinc_isum_bwd_FRAMESIZE   EQU     2
_ptr_postinc_isum_bwd_STKGUARD    EQU     0
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
                LDA     #_ptr_postinc_fwd
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #1
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
                LDA     #_ptr_postinc_fwd
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #2
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
                LDA     #_ptr_postinc_fwd
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
                TAX
                TYA
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_ptr_postinc_fwd
                PHA
                LDA     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #4
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
                LDA     #_ptr_postinc_fwd
                PHA
                LDA     #4
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
                LDA     #_ptr_postinc_bwd
                PHA
                LDA     #0
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
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_ptr_postinc_bwd
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #6
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
                LDA     #_ptr_postinc_bwd
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #7
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
                LDA     #_ptr_postinc_v
                PHA
                LDA     #0
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #10
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_ptr_postinc_v
                PHA
                LDA     #1
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #20
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                LDA     #_ptr_postinc_v
                PHA
                LDA     #2
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #30
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                PLA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_postinc_fwd
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ptr_postinc_sum_fwd
                PLY
                PLY
                PHA
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
                LDA     #_ptr_postinc_bwd+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ptr_postinc_sum_bwd
                PLY
                PLY
                PLY
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
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
                LDA     #_ptr_postinc_v+4
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ptr_postinc_isum_bwd
                PLY
                PLY
                PLY
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
                FGX2_RELOC_COUNT 8
