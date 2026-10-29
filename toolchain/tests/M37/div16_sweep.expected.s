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
                BCC     _div16_sweep_L1
                LDA     ur
                SEC
                SBC     _fcc_img0
                STA     ur
                LDA     uq
                CLC
                ADC     #1
                STA     uq
                BRA     _div16_sweep_L0
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
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                PEI     _fcc_img20
                PEI     _fcc_img21
                PEI     _fcc_img22
                PEI     _fcc_img23
                PEI     _fcc_img24
                TSC
                SEC
                SBC     #main_FRAMESIZE-18
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
                STA     _fcc_img22
                LDA     #0
                STA     _fcc_img16
_div16_sweep_L2
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #16
                BVC     _div16_sweep_L5
                EOR     #$8000
_div16_sweep_L5
                BMI     *+5
                BRL     _div16_sweep_L4
                LDA     #0
                STA     _fcc_img17
_div16_sweep_L6
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                TAX
                SEC
                SBC     #16
                BVC     _div16_sweep_L9
                EOR     #$8000
_div16_sweep_L9
                BMI     *+5
                BRL     _div16_sweep_L8
                LDA     _fcc_img16
                ASL
                TAX
                LDA:    nv,X
                STA     _fcc_img23
                LDA     _fcc_img17
                ASL
                TAX
                LDA:    dv,X
                STA     _fcc_img20
                LDX     #1000
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _div16_sweep_L10
                LDA     _fcc_img23
                LSR
                TAX
                LDA     _fcc_img20
                STA     _fcc_tmp_b
                TXA
                LDX     _fcc_tmp_b
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _div16_sweep_L10
                BRA     _div16_sweep_L7
_div16_sweep_L10
                LDA     _fcc_img20
                PHA
                LDA     _fcc_img23
                PHA
                FGX2_FARCALL refu
                PLY
                PLY
                LDA     _fcc_img23
                TAX
                LDA     _fcc_img20
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divu16
                PHA
                LDA     uq
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _div16_sweep_L11
                INC     _fcc_img22
_div16_sweep_L11
                LDA     _fcc_img23
                TAX
                LDA     _fcc_img20
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_modu16
                PHA
                LDA     ur
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _div16_sweep_L12
                INC     _fcc_img22
_div16_sweep_L12
_div16_sweep_L7
                INC     _fcc_img17
                BRL     _div16_sweep_L6
_div16_sweep_L8
_div16_sweep_L3
                INC     _fcc_img16
                BRL     _div16_sweep_L2
_div16_sweep_L4
                LDA     #0
                STA     _fcc_img16
_div16_sweep_L13
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img16
                TAX
                SEC
                SBC     #14
                BVC     _div16_sweep_L16
                EOR     #$8000
_div16_sweep_L16
                BMI     *+5
                BRL     _div16_sweep_L15
                LDA     #0
                STA     _fcc_img17
_div16_sweep_L17
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img17
                TAX
                SEC
                SBC     #10
                BVC     _div16_sweep_L20
                EOR     #$8000
_div16_sweep_L20
                BMI     *+5
                BRL     _div16_sweep_L19
                LDA     _fcc_img16
                ASL
                TAX
                LDA:    sn,X
                STA     _fcc_img21
                LDA     _fcc_img17
                ASL
                TAX
                LDA:    sd,X
                STA     _fcc_img18
                LDA     _fcc_img21
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
                BEQ     _div16_sweep_L21
                LDA     _fcc_img18
                CMP     #$FFFF
                BNE     _div16_sweep_L21
                BRL     _div16_sweep_L18
_div16_sweep_L21
                LDA     _fcc_img21
                TAX
                LDA     _fcc_img18
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_divs16
                STA     _fcc_img24
                LDA     _fcc_img21
                TAX
                LDA     _fcc_img18
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mods16
                STA     _fcc_img19
                LDA     _fcc_img24
                TAX
                LDA     _fcc_img18
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mul16
                CLC
                ADC     _fcc_img19
                TAX
                LDA     _fcc_img21
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _div16_sweep_L22
                INC     _fcc_img22
_div16_sweep_L22
                LDA     _fcc_img19
                CMP     #0
                BEQ     _div16_sweep_L23
                LDA     _fcc_img19
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                PHA
                LDA     _fcc_img21
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_lts16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _div16_sweep_L23
                INC     _fcc_img22
_div16_sweep_L23
                LDA     _fcc_img19
                BPL     _div16_sweep_L25
                LDA     _fcc_img19
                EOR     #$FFFF
                INC
                BRA     _div16_sweep_L26
_div16_sweep_L25
                LDA     _fcc_img19
_div16_sweep_L26
                PHA
                LDA     _fcc_img18
                BPL     _div16_sweep_L27
                LDA     _fcc_img18
                EOR     #$FFFF
                INC
                BRA     _div16_sweep_L28
_div16_sweep_L27
                LDA     _fcc_img18
_div16_sweep_L28
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                BVC     _div16_sweep_L29
                EOR     #$8000
_div16_sweep_L29
                BMI     _div16_sweep_L24
                INC     _fcc_img22
_div16_sweep_L24
_div16_sweep_L18
                INC     _fcc_img17
                BRL     _div16_sweep_L17
_div16_sweep_L19
_div16_sweep_L14
                INC     _fcc_img16
                BRL     _div16_sweep_L13
_div16_sweep_L15
                LDA     _fcc_img22
                BNE     _div16_sweep_L30
                LDA     #42
                BRA     _div16_sweep_L31
_div16_sweep_L30
                LDA     _fcc_img22
_div16_sweep_L31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-18
                TCS
                PLA
                STA     _fcc_img24
                PLA
                STA     _fcc_img23
                PLA
                STA     _fcc_img22
                PLA
                STA     _fcc_img21
                PLA
                STA     _fcc_img20
                PLA
                STA     _fcc_img19
                PLA
                STA     _fcc_img18
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     36
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
