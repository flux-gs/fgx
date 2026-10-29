                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from pidx_char.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _pidx_char_csum
_pidx_char_csum            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_pidx_char_csum_FRAMESIZE
                DO      _pidx_char_csum_STKGUARD
                BCC     _pidx_char_csum_stkovf
                CMP     _fcc_stkfloor
                BCS     _pidx_char_csum_stkok
_pidx_char_csum_stkovf       JMP     _fcc_stkoflow
                FIN
_pidx_char_csum_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_pidx_char_csum_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_pidx_char_csum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_pidx_char_csum_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      6+_pidx_char_csum_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_pidx_char_csum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_pidx_char_csum_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img3
                DO      8+_pidx_char_csum_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_pidx_char_csum_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_pidx_char_csum_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_pidx_char_L0
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
                BVC     _pidx_char_L3
                EOR     #$8000
_pidx_char_L3
                BPL     _pidx_char_L2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
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
                STA     _fcc_img1
_pidx_char_L1
                INC     _fcc_img0
                BRA     _pidx_char_L0
_pidx_char_L2
                LDA     _fcc_img1
                TAX
                SEC
                SBC     #65
                TAY
                TSC
                CLC
                ADC     #_pidx_char_csum_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_pidx_char_csum_FRAMESIZE   EQU     4
_pidx_char_csum_STKGUARD    EQU     0
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
                LDA     #_pidx_char_buf
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
                LDA     #_pidx_char_buf
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
                LDA     #_pidx_char_buf
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
                LDA     #_pidx_char_buf
                PHA
                LDA     #3
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
                LDA     #_pidx_char_buf
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _pidx_char_csum
                TAY
                TSC
                CLC
                ADC     #6
                TCS
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
                FGX2_RELOC_COUNT 4
