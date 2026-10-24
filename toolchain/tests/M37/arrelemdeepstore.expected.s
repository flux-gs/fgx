                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from arrelemdeepstore.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _arrelemdeepstore_clear
_arrelemdeepstore_clear            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_arrelemdeepstore_clear_FRAMESIZE
                DO      _arrelemdeepstore_clear_STKGUARD
                BCC     _arrelemdeepstore_clear_stkovf
                CMP     _fcc_stkfloor
                BCS     _arrelemdeepstore_clear_stkok
_arrelemdeepstore_clear_stkovf       JMP     _fcc_stkoflow
                FIN
_arrelemdeepstore_clear_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img0
_arrelemdeepstore_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #3
                BVC     _arrelemdeepstore_L3
                EOR     #$8000
_arrelemdeepstore_L3
                BMI     *+5
                BRL     _arrelemdeepstore_L2
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #4096
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                INC
                INC
                STA     _fcc_fpr0
                LDA     #8192
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #12288
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #$0004
                STA     _fcc_long_hi
                LDA     #$0000
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     _fcc_img0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #10
                STA     _fcc_fpr0
                LDA     #20480
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #12
                STA     _fcc_fpr0
                LDA     #24576
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
                LDA     _fcc_img0
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #28672
                CLC
                ADC     _fcc_img0
                STA     [_fcc_fpr0]
_arrelemdeepstore_L1
                INC     _fcc_img0
                BRL     _arrelemdeepstore_L0
_arrelemdeepstore_L2
                LDA     #32768
                STA     gt+64
                TAY
                TSC
                CLC
                ADC     #_arrelemdeepstore_clear_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemdeepstore_clear_FRAMESIZE   EQU     2
_arrelemdeepstore_clear_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gt
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                FGX2_FARCALL _arrelemdeepstore_clear
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #21930
                STA     [_fcc_fpr0]
                LDA     gt+24
                TAX
                CMP     #21930
                BEQ     _arrelemdeepstore_L4
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
_arrelemdeepstore_L4
                LDA     gt+4
                TAX
                CMP     #12288
                BEQ     _arrelemdeepstore_L5
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
_arrelemdeepstore_L5
                LDA     gt+44
                TAX
                CMP     #12290
                BEQ     _arrelemdeepstore_L6
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
_arrelemdeepstore_L6
                LDA     gt+22
                TAX
                CMP     #8193
                BEQ     _arrelemdeepstore_L7
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
_arrelemdeepstore_L7
                LDA     gt+20
                TAX
                CMP     #4097
                BEQ     _arrelemdeepstore_L8
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
_arrelemdeepstore_L8
                LDA     gt+64
                TAX
                CMP     #32768
                BEQ     _arrelemdeepstore_L9
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
_arrelemdeepstore_L9
                FGX2_FARCALL _arrelemdeepstore_clear
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                STA     _fcc_fpr0
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #4660
                STA     [_fcc_fpr0]
                LDA     gt+44
                TAX
                CMP     #4660
                BEQ     _arrelemdeepstore_L10
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
_arrelemdeepstore_L10
                LDA     gt+24
                TAX
                CMP     #12289
                BEQ     _arrelemdeepstore_L11
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
_arrelemdeepstore_L11
                LDA     gt+42
                TAX
                CMP     #8194
                BEQ     _arrelemdeepstore_L12
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
_arrelemdeepstore_L12
                LDA     gt+40
                TAX
                CMP     #4098
                BEQ     _arrelemdeepstore_L13
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
_arrelemdeepstore_L13
                FGX2_FARCALL _arrelemdeepstore_clear
                LDA     #0
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #14
                STA     _fcc_fpr0
                LDA     #3855
                STA     [_fcc_fpr0]
                LDA     gt+14
                TAX
                CMP     #3855
                BEQ     _arrelemdeepstore_L14
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
_arrelemdeepstore_L14
                LDA     gt+12
                TAX
                CMP     #24576
                BEQ     _arrelemdeepstore_L15
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
_arrelemdeepstore_L15
                LDA     gt+10
                TAX
                CMP     #20480
                BEQ     _arrelemdeepstore_L16
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
_arrelemdeepstore_L16
                LDA     gt+4
                TAX
                CMP     #12288
                BEQ     _arrelemdeepstore_L17
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
_arrelemdeepstore_L17
                LDA     gt+34
                TAX
                CMP     #28673
                BEQ     _arrelemdeepstore_L18
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
_arrelemdeepstore_L18
                FGX2_FARCALL _arrelemdeepstore_clear
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #6
                STA     _fcc_fpr0
                LDA     #$00AB
                STA     _fcc_long_hi
                LDA     #$CDEF
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                LDA     gt+48
                STA     _fcc_long_hi
                LDA     gt+46
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$00AB
                STA     _fcc_long_hi
                LDA     #$CDEF
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
                BEQ     _arrelemdeepstore_L19
                LDA     #30
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemdeepstore_L19
                LDA     gt+28
                STA     _fcc_long_hi
                LDA     gt+26
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0004
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
                BEQ     _arrelemdeepstore_L20
                LDA     #31
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemdeepstore_L20
                LDA     gt+44
                TAX
                CMP     #12290
                BEQ     _arrelemdeepstore_L21
                LDA     #32
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_arrelemdeepstore_L21
                FGX2_FARCALL _arrelemdeepstore_clear
                LDA     #1
                STA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     #32382
                STA     [_fcc_fpr0]
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                CLC
                ADC     #gt
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CLC
                ADC     #4
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                TAX
                CMP     #32382
                BEQ     _arrelemdeepstore_L22
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
_arrelemdeepstore_L22
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
main_FRAMESIZE   EQU     2
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 8
