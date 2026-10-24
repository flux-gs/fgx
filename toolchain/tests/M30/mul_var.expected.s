                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from mul_var.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _mul_var_iv
_mul_var_iv            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_mul_var_iv_FRAMESIZE
                DO      _mul_var_iv_STKGUARD
                BCC     _mul_var_iv_stkovf
                CMP     _fcc_stkfloor
                BCS     _mul_var_iv_stkok
_mul_var_iv_stkovf       JMP     _fcc_stkoflow
                FIN
_mul_var_iv_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_mul_var_iv_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mul_var_iv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mul_var_iv_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_mul_var_iv_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_iv_FRAMESIZE   EQU     0
_mul_var_iv_STKGUARD    EQU     0
                FGX2_EXPORT _mul_var_uv
_mul_var_uv            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_mul_var_uv_FRAMESIZE
                DO      _mul_var_uv_STKGUARD
                BCC     _mul_var_uv_stkovf
                CMP     _fcc_stkfloor
                BCS     _mul_var_uv_stkok
_mul_var_uv_stkovf       JMP     _fcc_stkoflow
                FIN
_mul_var_uv_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_mul_var_uv_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mul_var_uv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mul_var_uv_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_mul_var_uv_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_uv_FRAMESIZE   EQU     0
_mul_var_uv_STKGUARD    EQU     0
                FGX2_EXPORT _mul_var_lv
_mul_var_lv            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_mul_var_lv_FRAMESIZE
                DO      _mul_var_lv_STKGUARD
                BCC     _mul_var_lv_stkovf
                CMP     _fcc_stkfloor
                BCS     _mul_var_lv_stkok
_mul_var_lv_stkovf       JMP     _fcc_stkoflow
                FIN
_mul_var_lv_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_mul_var_lv_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_mul_var_lv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_mul_var_lv_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+_mul_var_lv_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_mul_var_lv_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_mul_var_lv_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #_mul_var_lv_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_lv_FRAMESIZE   EQU     0
_mul_var_lv_STKGUARD    EQU     0
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
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #1234
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L0
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L0
                LDA     #1234
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L1
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L1
                LDA     #1
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #$FFF9
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #$FFF9
                BNE     *+5
                BRL     _mul_var_L2
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L2
                LDA     #$FFF9
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #$FFF9
                BNE     *+5
                BRL     _mul_var_L3
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L3
                LDA     #300
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #300
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #24464
                BNE     *+5
                BRL     _mul_var_L4
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L4
                LDA     #$FFFF
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #$FFFF
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _mul_var_L5
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L5
                LDA     #$FFFD
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #7
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #$FFEB
                BNE     *+5
                BRL     _mul_var_L6
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L6
                LDA     #7
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #$FFFD
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #$FFEB
                BNE     *+5
                BRL     _mul_var_L7
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L7
                LDA     #65535
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                PHA
                LDA     #65535
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #1
                BNE     *+5
                BRL     _mul_var_L8
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L8
                LDA     #12345
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$D431
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #28393
                BNE     *+5
                BRL     _mul_var_L9
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L9
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$D431
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                PHA
                LDA     #12345
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #28393
                BNE     *+5
                BRL     _mul_var_L10
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L10
                LDA     #32768
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L11
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L11
                LDA     #2
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                PHA
                LDA     #32768
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L12
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L12
                LDA     #255
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                PHA
                LDA     #255
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #65025
                BNE     *+5
                BRL     _mul_var_L13
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L13
                LDA     #181
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #181
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #32761
                BNE     *+5
                BRL     _mul_var_L14
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L14
                LDA     #32767
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL _mul_var_iv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #32765
                BNE     *+5
                BRL     _mul_var_L15
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L15
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                PHA
                FGX2_FARCALL _mul_var_uv
                TAY
                PLA
                TYA
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                TAX
                TXA
                CMP     #4096
                BNE     *+5
                BRL     _mul_var_L16
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L16
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L17
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L17
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$E240
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L18
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L18
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L19
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L19
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$540B
                STA     _fcc_long_hi
                LDA     #$E400
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L20
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L20
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0003
                STA     _fcc_long_hi
                LDA     #$3450
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L21
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L21
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0003
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0003
                STA     _fcc_long_hi
                LDA     #$3450
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L22
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L22
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$473A
                STA     _fcc_long_hi
                LDA     #$DDB8
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L23
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L23
                LDA     #$0123
                STA     _fcc_long_hi
                LDA     #$4567
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$473A
                STA     _fcc_long_hi
                LDA     #$DDB8
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L24
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L24
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L25
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L25
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L26
                LDA     #27
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L26
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$B505
                JSR     _fcc_long_neg
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$B505
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7FFF
                STA     _fcc_long_hi
                LDA     #$EDE7
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L27
                LDA     #28
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L27
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$86A0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL _mul_var_lv
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_mul
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$7960
                STA     _fcc_long_hi
                LDA     #$0000
                JSR     _fcc_long_neg
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ne
                CMP     #0
                BNE     *+5
                BRL     _mul_var_L28
                LDA     #29
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_mul_var_L28
                LDA     #42
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
                FGX2_RELOC_COUNT 63
