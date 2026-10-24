                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from strlen_test.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT clearbuf
clearbuf            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #clearbuf_FRAMESIZE
                DO      clearbuf_STKGUARD
                BCC     clearbuf_stkovf
                CMP     _fcc_stkfloor
                BCS     clearbuf_stkok
clearbuf_stkovf       JMP     _fcc_stkoflow
                FIN
clearbuf_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+clearbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+clearbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+clearbuf_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_strlen_test_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _strlen_test_L2
                EOR     #$8000
_strlen_test_L2
                BPL     _strlen_test_L1
                DO      8+clearbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+clearbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+clearbuf_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+clearbuf_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+clearbuf_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+clearbuf_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                TAY
                LDA     _fcc_ptr+2
                PHA
                TYA
                PHA
                LDA     #0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                SEP     #$20
                MX      %10
                STA     [_fcc_ptr]
                REP     #$20
                MX      %00
                PLA
                PLA
                TYA
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _strlen_test_L0
_strlen_test_L1
                TAY
                TSC
                CLC
                ADC     #clearbuf_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
clearbuf_FRAMESIZE   EQU     2
clearbuf_STKGUARD    EQU     0
                FGX2_EXPORT strlen_
strlen_            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #strlen__FRAMESIZE
                DO      strlen__STKGUARD
                BCC     strlen__stkovf
                CMP     _fcc_stkfloor
                BCS     strlen__stkok
strlen__stkovf       JMP     _fcc_stkoflow
                FIN
strlen__stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+strlen__FRAMESIZE/256
                TSC
                CLC
                ADC     #6+strlen__FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+strlen__FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      8+strlen__FRAMESIZE/256
                TSC
                CLC
                ADC     #8+strlen__FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+strlen__FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img2
                LDA     #0
                STA     _fcc_img0
_strlen_test_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     [_fcc_img1]
                AND     #$00FF
                CMP     #0
                BEQ     _strlen_test_L4
                LDA     _fcc_img2
                STA     _fcc_ptr+2
                LDA     _fcc_img1
                INC
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img0
                BRA     _strlen_test_L3
_strlen_test_L4
                LDA     _fcc_img0
                TAY
                TSC
                CLC
                ADC     #strlen__FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
strlen__FRAMESIZE   EQU     2
strlen__STKGUARD    EQU     0
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
                LDA     #8
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
                FGX2_FARCALL clearbuf
                TSC
                CLC
                ADC     #6
                TCS
                LDA     _fcc_fb
                CLC
                ADC     #0
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #14
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
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #14
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
                LDA     #14
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
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL strlen_
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 6
