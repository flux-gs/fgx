                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ptr_bigframe.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ptr_bigframe_bigframe
_ptr_bigframe_bigframe            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ptr_bigframe_bigframe_FRAMESIZE
                DO      _ptr_bigframe_bigframe_STKGUARD
                BCC     _ptr_bigframe_bigframe_stkovf
                CMP     _fcc_stkfloor
                BCS     _ptr_bigframe_bigframe_stkok
_ptr_bigframe_bigframe_stkovf       JMP     _fcc_stkoflow
                FIN
_ptr_bigframe_bigframe_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_ptr_bigframe_bigframe_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ptr_bigframe_bigframe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ptr_bigframe_bigframe_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                DO      8+_ptr_bigframe_bigframe_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ptr_bigframe_bigframe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ptr_bigframe_bigframe_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     3,S   ; fccstk d=0 b=3
                DO      10+_ptr_bigframe_bigframe_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_ptr_bigframe_bigframe_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_ptr_bigframe_bigframe_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img3
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img1
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #0
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
                LDA     #0
                STA     _fcc_img0
_ptr_bigframe_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _ptr_bigframe_L3
                EOR     #$8000
_ptr_bigframe_L3
                BPL     _ptr_bigframe_L2
                LDA     _fcc_img1
                PHA
                LDA     [_fcc_img3]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                CLC
                ADC     #1
                STA     _fcc_img3
_ptr_bigframe_L1
                INC     _fcc_img0
                BRA     _ptr_bigframe_L0
_ptr_bigframe_L2
                LDA     _fcc_img1
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #10
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
                ADC     #_ptr_bigframe_bigframe_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ptr_bigframe_bigframe_FRAMESIZE   EQU     310
_ptr_bigframe_bigframe_STKGUARD    EQU     1
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
                LDA     #_ptr_bigframe_data
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #9
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
                LDA     #_ptr_bigframe_data
                PHA
                LDA     #1
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
                SEP     #$20
                MX      %10
                STA:    $0000,X
                REP     #$20
                MX      %00
                PLA
                LDA     #_ptr_bigframe_data
                PHA
                LDA     #2
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #11
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
                LDA     #_ptr_bigframe_data
                PHA
                LDA     #3
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #12
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
                LDA     #4
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_ptr_bigframe_data
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ptr_bigframe_bigframe
                PLY
                PLY
                PLY
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
                FGX2_RELOC_COUNT 4
