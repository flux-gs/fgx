                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from longparamseed.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT store
store            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #store_FRAMESIZE
                DO      store_STKGUARD
                BCC     store_stkovf
                CMP     _fcc_stkfloor
                BCS     store_stkok
store_stkovf       JMP     _fcc_stkoflow
                FIN
store_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+store_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+store_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+store_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img1
                DO      10+store_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+store_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+store_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img2
                DO      12+store_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+store_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+store_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img3
                DO      8+store_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+store_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+store_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                TAX
                LDA     #0
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _longparamseed_L1
                EOR     #$8000
_longparamseed_L1
                BMI     *+5
                BRL     _longparamseed_L0
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+store_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+store_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+store_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                EOR     #$FFFF
                INC
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shru
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
                BRL     _longparamseed_L2
_longparamseed_L0
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      12+store_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+store_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+store_FRAMESIZE,S   ; fccstk d=4 b=8 fs
                FIN
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shl
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
_longparamseed_L2
                LDA     #0
                STA     _fcc_img0
_longparamseed_L3
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     *+5
                BRL     _longparamseed_L5
                LDA     #img
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     _fcc_img2
                AND     #$00FF
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
                LDA     _fcc_img3
                STA     _fcc_long_hi
                LDA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #8
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_shru
                STA     _fcc_img2
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img3
                TYA
_longparamseed_L4
                INC     _fcc_img0
                BRL     _longparamseed_L3
_longparamseed_L5
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #store_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
store_FRAMESIZE   EQU     2
store_STKGUARD    EQU     0
                FGX2_EXPORT top
top            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #top_FRAMESIZE
                DO      top_STKGUARD
                BCC     top_stkovf
                CMP     _fcc_stkfloor
                BCS     top_stkok
top_stkovf       JMP     _fcc_stkoflow
                FIN
top_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+top_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+top_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+top_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img2
                DO      8+top_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+top_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+top_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img3
                DO      10+top_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+top_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+top_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_longparamseed_L6
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
                BVC     _longparamseed_L9
                EOR     #$8000
_longparamseed_L9
                BMI     *+5
                BRL     _longparamseed_L8
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_long_hi
                LDX     #0
                CMP     #$8000
                BCC     _longparamseed_L10
                LDX     #$FFFF
_longparamseed_L10
                STX     _fcc_long_hi
                PHA
                LDA     _fcc_img4
                STA     _fcc_long_hi
                LDA     _fcc_img3
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
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
                JSR     _fcc_long_and
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
_longparamseed_L7
                INC     _fcc_img0
                BRL     _longparamseed_L6
_longparamseed_L8
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #top_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
top_FRAMESIZE   EQU     4
top_STKGUARD    EQU     0
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
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                PHA
                LDA     #4
                PHA
                FGX2_FARCALL store
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #120
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L12
                LDA     #1
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #86
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L12
                LDA     #0
                BRL     _longparamseed_L13
_longparamseed_L12
                LDA     #1
_longparamseed_L13
                CMP     #0
                BNE     *+5
                BRL     _longparamseed_L11
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
_longparamseed_L11
                LDA     #2
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #52
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L15
                LDA     #3
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #18
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L15
                LDA     #0
                BRL     _longparamseed_L16
_longparamseed_L15
                LDA     #1
_longparamseed_L16
                CMP     #0
                BNE     *+5
                BRL     _longparamseed_L14
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
_longparamseed_L14
                LDA     #$CAFE
                STA     _fcc_long_hi
                LDA     #$BABE
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #8
                EOR     #$FFFF
                INC
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL store
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #186
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L20
                LDA     #1
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #254
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L20
                LDA     #0
                BRL     _longparamseed_L21
_longparamseed_L20
                LDA     #1
_longparamseed_L21
                CMP     #0
                BEQ     *+5
                BRL     _longparamseed_L18
                LDA     #2
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #202
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L18
                LDA     #0
                BRL     _longparamseed_L19
_longparamseed_L18
                LDA     #1
_longparamseed_L19
                CMP     #0
                BNE     *+5
                BRL     _longparamseed_L17
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
_longparamseed_L17
                LDA     #$00AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #4
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL store
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #240
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L25
                LDA     #1
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #222
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L25
                LDA     #0
                BRL     _longparamseed_L26
_longparamseed_L25
                LDA     #1
_longparamseed_L26
                CMP     #0
                BEQ     *+5
                BRL     _longparamseed_L23
                LDA     #2
                TAX
                LDA:    img,X
                AND     #$00FF
                TAX
                LDA     #188
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     *+5
                BRL     _longparamseed_L23
                LDA     #0
                BRL     _longparamseed_L24
_longparamseed_L23
                LDA     #1
_longparamseed_L24
                CMP     #0
                BNE     *+5
                BRL     _longparamseed_L22
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
_longparamseed_L22
                LDA     #$0005
                STA     _fcc_long_hi
                LDA     #$0001
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #3
                PHA
                FGX2_FARCALL top
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                LDA     #18
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _longparamseed_L27
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
_longparamseed_L27
                LDA     #$0007
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
                PHA
                FGX2_FARCALL top
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                LDA     #14
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _longparamseed_L28
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
_longparamseed_L28
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
                FGX2_RELOC_COUNT 9
