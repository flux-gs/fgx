                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from div16_sweep.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT refu
refu            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #refu_FRAMESIZE
                DO      refu_STKGUARD
                BCC     refu_stkovf
                CMP     _fcc_stkfloor
                BCS     refu_stkok
refu_stkovf       JMP     _fcc_stkoflow
                FIN
refu_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+refu_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+refu_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+refu_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img0
                LDA     #0
                STA     uq
                DO      6+refu_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+refu_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+refu_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     ur
_div16_sweep_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     ur
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     *+5
                BRL     _div16_sweep_L1
                LDA     ur
                SEC
                SBC     _fcc_img0
                STA     ur
                LDA     uq
                CLC
                ADC     #1
                STA     uq
                BRL     _div16_sweep_L0
_div16_sweep_L1
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #refu_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
refu_FRAMESIZE   EQU     0
refu_STKGUARD    EQU     0
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
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
_div16_sweep_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                SEC
                SBC     #16
                BVC     _div16_sweep_L5
                EOR     #$8000
_div16_sweep_L5
                BMI     *+5
                BRL     _div16_sweep_L4
                LDA     #0
                STA     3,S   ; fccstk d=0 b=3
_div16_sweep_L6
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                TXA
                SEC
                SBC     #16
                BVC     _div16_sweep_L9
                EOR     #$8000
_div16_sweep_L9
                BMI     *+5
                BRL     _div16_sweep_L8
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                TAX
                LDA:    nv,X
                STA     15,S   ; fccstk d=0 b=15
                LDA     3,S   ; fccstk d=0 b=3
                ASL
                TAX
                LDA:    dv,X
                STA     17,S   ; fccstk d=0 b=17
                TAX
                TXA
                LDX     #1000
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _div16_sweep_L11
                LDA     15,S   ; fccstk d=0 b=15
                LSR
                PHA
                LDA     19,S   ; fccstk d=2 b=17
                STA     _fcc_tmp_b
                PLA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _div16_sweep_L11
                LDA     #1
                BRL     _div16_sweep_L12
_div16_sweep_L11
                LDA     #0
_div16_sweep_L12
                CMP     #0
                BNE     *+5
                BRL     _div16_sweep_L10
                BRL     _div16_sweep_L7
_div16_sweep_L10
                LDA     17,S   ; fccstk d=0 b=17
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                PHA
                FGX2_FARCALL refu
                TAY
                PLA
                PLA
                TYA
                LDA     15,S   ; fccstk d=0 b=15
                TAX
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divu16
                PHA
                LDA     uq
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _div16_sweep_L13
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
_div16_sweep_L13
                LDA     15,S   ; fccstk d=0 b=15
                TAX
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_modu16
                PHA
                LDA     ur
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _div16_sweep_L14
                LDA     5,S   ; fccstk d=0 b=5
                CLC
                ADC     #1
                STA     5,S   ; fccstk d=0 b=5
_div16_sweep_L14
_div16_sweep_L7
                LDA     3,S   ; fccstk d=0 b=3
                CLC
                ADC     #1
                STA     3,S   ; fccstk d=0 b=3
                BRL     _div16_sweep_L6
_div16_sweep_L8
_div16_sweep_L3
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     #1
                STA     1,S   ; fccstk d=0 b=1
                BRL     _div16_sweep_L2
_div16_sweep_L4
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_img0
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_img1
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_img2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_img3
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_img4
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_img5
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_img6
_div16_sweep_L15
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img4
                TAX
                TXA
                SEC
                SBC     #14
                BVC     _div16_sweep_L18
                EOR     #$8000
_div16_sweep_L18
                BMI     *+5
                BRL     _div16_sweep_L17
                LDA     #0
                STA     _fcc_img3
_div16_sweep_L19
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img3
                TAX
                TXA
                SEC
                SBC     #10
                BVC     _div16_sweep_L22
                EOR     #$8000
_div16_sweep_L22
                BMI     *+5
                BRL     _div16_sweep_L21
                LDA     _fcc_img4
                ASL
                TAX
                LDA:    sn,X
                STA     _fcc_img2
                LDA     _fcc_img3
                ASL
                TAX
                LDA:    sd,X
                STA     _fcc_img0
                LDA     _fcc_img2
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                JSR     _fcc_long_from_int
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_long_b_lo
                LDX     _fcc_long_b_hi
                STX     _fcc_long_hi
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_eq
                CMP     #0
                BNE     *+5
                BRL     _div16_sweep_L24
                LDA     _fcc_img0
                CMP     #$FFFF
                BEQ     *+5
                BRL     _div16_sweep_L24
                LDA     #1
                BRL     _div16_sweep_L25
_div16_sweep_L24
                LDA     #0
_div16_sweep_L25
                CMP     #0
                BNE     *+5
                BRL     _div16_sweep_L23
                BRL     _div16_sweep_L20
_div16_sweep_L23
                LDA     _fcc_img2
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divs16
                STA     _fcc_img6
                LDA     _fcc_img2
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mods16
                STA     _fcc_img1
                LDA     _fcc_img6
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_img1
                TAX
                LDA     _fcc_img2
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _div16_sweep_L26
                INC     _fcc_img5
_div16_sweep_L26
                LDA     _fcc_img1
                CMP     #0
                BNE     *+5
                BRL     _div16_sweep_L28
                LDA     _fcc_img1
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                PHA
                LDA     _fcc_img2
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _div16_sweep_L28
                LDA     #1
                BRL     _div16_sweep_L29
_div16_sweep_L28
                LDA     #0
_div16_sweep_L29
                CMP     #0
                BNE     *+5
                BRL     _div16_sweep_L27
                INC     _fcc_img5
_div16_sweep_L27
                LDA     _fcc_img1
                CMP     #0
                BMI     *+5
                BRL     _div16_sweep_L31
                LDA     _fcc_img1
                EOR     #$FFFF
                INC
                BRL     _div16_sweep_L32
_div16_sweep_L31
                LDA     _fcc_img1
_div16_sweep_L32
                PHA
                LDA     _fcc_img0
                CMP     #0
                BMI     *+5
                BRL     _div16_sweep_L33
                LDA     _fcc_img0
                EOR     #$FFFF
                INC
                BRL     _div16_sweep_L34
_div16_sweep_L33
                LDA     _fcc_img0
_div16_sweep_L34
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _div16_sweep_L35
                EOR     #$8000
_div16_sweep_L35
                BPL     *+5
                BRL     _div16_sweep_L30
                INC     _fcc_img5
_div16_sweep_L30
_div16_sweep_L20
                INC     _fcc_img3
                BRL     _div16_sweep_L19
_div16_sweep_L21
_div16_sweep_L16
                INC     _fcc_img4
                BRL     _div16_sweep_L15
_div16_sweep_L17
                LDA     _fcc_img0
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_img1
                STA     9,S   ; fccstk d=0 b=9
                LDA     _fcc_img2
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_img3
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_img4
                STA     1,S   ; fccstk d=0 b=1
                LDA     _fcc_img5
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_img6
                STA     7,S   ; fccstk d=0 b=7
                LDA     5,S   ; fccstk d=0 b=5
                CMP     #0
                BEQ     *+5
                BRL     _div16_sweep_L36
                LDA     #42
                BRL     _div16_sweep_L37
_div16_sweep_L36
                LDA     5,S   ; fccstk d=0 b=5
_div16_sweep_L37
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     18
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
