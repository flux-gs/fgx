                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from mods_pow2.c
;---------------------------------------

                MX      %00
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
                STA     _fcc_img1
                LDA     #4
                STA     m4
                LDA     #512
                STA     m512
                LDA     #1
                STA     m1
                LDA     #0
                STA     _fcc_img2
                LDA     #$FBB4
                STA     _fcc_img0
_mods_pow2_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                LDX     #1100
                STA     _fcc_tmp_b
                TXA
                SEC
                SBC     _fcc_tmp_b
                BVC     _mods_pow2_L3
                EOR     #$8000
_mods_pow2_L3
                BPL     *+5
                BRL     _mods_pow2_L2
                LDA     _fcc_img0
                CMP     #$8000
                BCC     _mods_pow2_L5
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L6
_mods_pow2_L5
                AND     #3
_mods_pow2_L6
                PHA
                LDA     _fcc_img0
                PHA
                LDA     m4
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mods16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _mods_pow2_L4
                INC     _fcc_img2
_mods_pow2_L4
                LDA     _fcc_img0
                CMP     #$8000
                BCC     _mods_pow2_L8
                EOR     #$FFFF
                INC
                AND     #511
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L9
_mods_pow2_L8
                AND     #511
_mods_pow2_L9
                PHA
                LDA     _fcc_img0
                PHA
                LDA     m512
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mods16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _mods_pow2_L7
                INC     _fcc_img2
_mods_pow2_L7
                LDA     _fcc_img0
                CMP     #$8000
                BCC     _mods_pow2_L11
                CLC
                ADC     #3
_mods_pow2_L11
                CMP     #$8000
                ROR
                CMP     #$8000
                ROR
                ASL
                ASL
                PHA
                LDA     _fcc_img0
                CMP     #$8000
                BCC     _mods_pow2_L12
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L13
_mods_pow2_L12
                AND     #3
_mods_pow2_L13
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAX
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     *+5
                BRL     _mods_pow2_L10
                INC     _fcc_img2
_mods_pow2_L10
_mods_pow2_L1
                INC     _fcc_img0
                BRL     _mods_pow2_L0
_mods_pow2_L2
                LDA     _fcc_img2
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L14
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #1
                STA     _fcc_img1
_mods_pow2_L14
                LDA     #$FFFF
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L16
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L17
_mods_pow2_L16
                AND     #3
_mods_pow2_L17
                CMP     #$FFFF
                BEQ     *+5
                BRL     _mods_pow2_L15
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #2
                STA     _fcc_img1
_mods_pow2_L15
                LDA     #$FFFC
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L19
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L20
_mods_pow2_L19
                AND     #3
_mods_pow2_L20
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L18
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #4
                STA     _fcc_img1
_mods_pow2_L18
                LDA     #$FFF9
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L22
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L23
_mods_pow2_L22
                AND     #3
_mods_pow2_L23
                CMP     #$FFFD
                BEQ     *+5
                BRL     _mods_pow2_L21
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #8
                STA     _fcc_img1
_mods_pow2_L21
                LDA     #7
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L25
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L26
_mods_pow2_L25
                AND     #3
_mods_pow2_L26
                TAX
                TXA
                CMP     #3
                BEQ     *+5
                BRL     _mods_pow2_L24
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #16
                STA     _fcc_img1
_mods_pow2_L24
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L28
                EOR     #$FFFF
                INC
                AND     #1
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L29
_mods_pow2_L28
                AND     #1
_mods_pow2_L29
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L27
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #32
                STA     _fcc_img1
_mods_pow2_L27
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8000
                JSR     _fcc_long_neg
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L31
                EOR     #$FFFF
                INC
                AND     #16383
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L32
_mods_pow2_L31
                AND     #16383
_mods_pow2_L32
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L30
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #64
                STA     _fcc_img1
_mods_pow2_L30
                LDA     #$8001
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L34
                EOR     #$FFFF
                INC
                AND     #16383
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L35
_mods_pow2_L34
                AND     #16383
_mods_pow2_L35
                CMP     #$C001
                BEQ     *+5
                BRL     _mods_pow2_L33
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #128
                STA     _fcc_img1
_mods_pow2_L33
                LDA     #32767
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L37
                EOR     #$FFFF
                INC
                AND     #16383
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L38
_mods_pow2_L37
                AND     #16383
_mods_pow2_L38
                TAX
                TXA
                CMP     #16383
                BEQ     *+5
                BRL     _mods_pow2_L36
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #256
                STA     _fcc_img1
_mods_pow2_L36
                LDA     #$FFFB
                STA     a
                LDA     #0
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L40
                LDA     a
                TAX
                LDA     m1
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_mods16
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L40
                LDA     #1
                BRL     _mods_pow2_L41
_mods_pow2_L40
                LDA     #0
_mods_pow2_L41
                CMP     #0
                BNE     *+5
                BRL     _mods_pow2_L39
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #512
                STA     _fcc_img1
_mods_pow2_L39
                LDA     #2024
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L45
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L46
_mods_pow2_L45
                AND     #3
_mods_pow2_L46
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L43
                LDA     a
                LDX     #100
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                CMP     #0
                BNE     *+5
                BRL     _mods_pow2_L43
                LDA     #1
                BRL     _mods_pow2_L44
_mods_pow2_L43
                LDA     #0
_mods_pow2_L44
                CMP     #0
                BNE     *+5
                BRL     _mods_pow2_L42
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #1024
                STA     _fcc_img1
_mods_pow2_L42
                LDA     #1900
                STA     a
                CMP     #$8000
                BCC     _mods_pow2_L52
                EOR     #$FFFF
                INC
                AND     #3
                EOR     #$FFFF
                INC
                BRA     _mods_pow2_L53
_mods_pow2_L52
                AND     #3
_mods_pow2_L53
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L50
                LDA     a
                LDX     #100
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                CMP     #0
                BNE     *+5
                BRL     _mods_pow2_L50
                LDA     #1
                BRL     _mods_pow2_L51
_mods_pow2_L50
                LDA     #0
_mods_pow2_L51
                CMP     #0
                BEQ     *+5
                BRL     _mods_pow2_L48
                LDA     a
                LDX     #400
                STX     _fcc_tmp_b
                JSR     _fcc_mods16
                CMP     #0
                BNE     *+5
                BRL     _mods_pow2_L48
                LDA     #0
                BRL     _mods_pow2_L49
_mods_pow2_L48
                LDA     #1
_mods_pow2_L49
                CMP     #0
                BEQ     _mods_pow2_L54
                LDA     #0
                BRA     _mods_pow2_L55
_mods_pow2_L54
                LDA     #1
_mods_pow2_L55
                CMP     #0
                BNE     *+5
                BRL     _mods_pow2_L47
                LDA     _fcc_img1
                TAX
                TXA
                CLC
                ADC     #2048
                STA     _fcc_img1
_mods_pow2_L47
                LDA     _fcc_img1
                TAX
                TXA
                CMP     #4095
                BEQ     *+5
                BRL     _mods_pow2_L56
                LDA     #42
                BRL     _mods_pow2_L57
_mods_pow2_L56
                LDA     _fcc_img1
_mods_pow2_L57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     6
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
