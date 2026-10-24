                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from typedefunsigned.c
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
                LDA     #$8589
                STA     _fcc_img0
                LDA     #$8589
                STA     _fcc_img1
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$5DC4
                STA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img5
                TYA
                LDA     _fcc_img0
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                PHA
                LDA     _fcc_img1
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _typedefunsigned_L0
                LDA     #43
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L0
                LDA     _fcc_img0
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _typedefunsigned_L1
                LDA     #44
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L1
                LDA     #$8589
                STA     gt
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$8589
                STA     gd
                LDA     gt
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                PHA
                LDA     gd
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _typedefunsigned_L2
                LDA     #45
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L2
                LDA     gt
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_lts
                CMP     #0
                BEQ     _typedefunsigned_L3
                LDA     #46
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L3
                LDA     #$9C40
                STA     _fcc_img0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     _fcc_img1
                LDA     _fcc_img0
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_gtu16
                PHA
                LDA     _fcc_img1
                TAX
                LDA     #10
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_gtu16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _typedefunsigned_L4
                LDA     #47
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L4
                LDA     _fcc_img0
                TAX
                LDX     #10
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCC     _typedefunsigned_L5
                LDA     #48
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L5
                LDA     #$9C40
                STA     _fcc_img0
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     _fcc_img1
                LDA     _fcc_img0
                LDX     #100
                STX     _fcc_tmp_b
                JSR     _fcc_divu16
                PHA
                LDA     _fcc_img1
                LDX     #100
                STX     _fcc_tmp_b
                JSR     _fcc_divu16
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _typedefunsigned_L6
                LDA     #49
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L6
                LDA     _fcc_img0
                LDX     #100
                STX     _fcc_tmp_b
                JSR     _fcc_divu16
                TAX
                CMP     #400
                BEQ     _typedefunsigned_L7
                LDA     #50
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L7
                LDA     #32768
                STA     _fcc_img0
                LDA     #32768
                STA     _fcc_img1
                LDA     _fcc_img0
                LSR
                LSR
                LSR
                LSR
                TAX
                LDA     _fcc_img1
                LSR
                LSR
                LSR
                LSR
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _typedefunsigned_L8
                LDA     #51
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L8
                LDA     _fcc_img0
                LSR
                LSR
                LSR
                LSR
                TAX
                CMP     #2048
                BEQ     _typedefunsigned_L9
                LDA     #52
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L9
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     _fcc_img4
                TAY
                LDA     _fcc_long_hi
                STA     _fcc_img5
                TYA
                LDA     _fcc_img4
                PHA
                LDA     _fcc_img5
                STA     _fcc_long_hi
                LDA     _fcc_img4
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _typedefunsigned_L10
                LDA     #53
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L10
                LDA     #$9C40
                STA     _fcc_img2
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_img2
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                LDX     #0
                STX     _fcc_long_hi
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
                BEQ     _typedefunsigned_L11
                LDA     #54
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L11
                LDA     _fcc_img2
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$9C40
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
                BEQ     _typedefunsigned_L12
                LDA     #55
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L12
                LDA     #200
                STA     _fcc_img3
                LDA     #200
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_img3
                AND     #$00FF
                TAX
                LDA     11,S   ; fccstk d=0 b=11
                AND     #$00FF
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _typedefunsigned_L13
                LDA     #56
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L13
                LDA     _fcc_img3
                AND     #$00FF
                TAX
                CMP     #200
                BEQ     _typedefunsigned_L14
                LDA     #57
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_typedefunsigned_L14
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
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 2
