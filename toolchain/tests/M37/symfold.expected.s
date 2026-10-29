                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from symfold.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT take
take            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #take_FRAMESIZE
                DO      take_STKGUARD
                BCC     take_stkovf
                CMP     _fcc_stkfloor
                BCS     take_stkok
take_stkovf       JMP     _fcc_stkoflow
                FIN
take_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+take_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+take_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+take_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+take_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                PHA
                DO      12+take_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+take_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+take_FRAMESIZE,S   ; fccstk d=2 b=10 fs
                FIN
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #take_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
take_FRAMESIZE   EQU     0
take_STKGUARD    EQU     0
                FGX2_EXPORT addr
addr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #addr_FRAMESIZE
                DO      addr_STKGUARD
                BCC     addr_stkovf
                CMP     _fcc_stkfloor
                BCS     addr_stkok
addr_stkovf       JMP     _fcc_stkoflow
                FIN
addr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+addr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+addr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+addr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+addr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+addr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+addr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                TSC
                CLC
                ADC     #addr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
addr_FRAMESIZE   EQU     0
addr_STKGUARD    EQU     0
                FGX2_EXPORT below
below            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #below_FRAMESIZE
                DO      below_STKGUARD
                BCC     below_stkovf
                CMP     _fcc_stkfloor
                BCS     below_stkok
below_stkovf       JMP     _fcc_stkoflow
                FIN
below_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+below_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+below_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+below_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+below_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+below_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+below_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+below_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+below_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+below_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_fpr0+2
                DO      14+below_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+below_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+below_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_ltu
                TAY
                TSC
                CLC
                ADC     #below_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
below_FRAMESIZE   EQU     0
below_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                TSC
                SEC
                SBC     #main_FRAMESIZE-4
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
                STA     3,S   ; fccstk d=0 b=3
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #3
                STA     [_fcc_fpr0]
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     #buf
                STA     _fcc_fpr1
                PLA
                LDA     _fcc_fpr1
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr1+2
                LDY     #4
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #7
                SEP     #$20
                MX      %10
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     tab+16
                DEC
                STA     tab+16
                BMI     _symfold_L0
                LDA     tab+18
                STA     _fcc_tmp_b
                CLC
                ADC     #1
                STA     tab+18
                LDA     tab+18+2
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BRA     _symfold_L1
_symfold_L0
                LDA     #$FFFF
_symfold_L1
                STA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #97
                BEQ     _symfold_L2
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L2
                LDA     tab+16
                DEC
                STA     tab+16
                BMI     _symfold_L3
                LDA     tab+18
                STA     _fcc_tmp_b
                CLC
                ADC     #1
                STA     tab+18
                LDA     tab+18+2
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BRA     _symfold_L4
_symfold_L3
                LDA     #$FFFF
_symfold_L4
                STA     5,S   ; fccstk d=0 b=5
                TAX
                CMP     #98
                BEQ     _symfold_L5
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L5
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                TAX
                CMP     #1
                BNE     _symfold_L7
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                PHA
                INY
                INY
                LDA     [_fcc_fpr0],Y
                STA     _fcc_fpr0+2
                PLA
                STA     _fcc_fpr0
                LDA     #2
                CLC
                ADC     #buf
                STA     _fcc_fpr1
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _symfold_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _symfold_L8
                LDA     #0
                BRA     _symfold_L9
_symfold_L8
                LDA     #1
_symfold_L9
                CMP     #0
                BEQ     _symfold_L6
_symfold_L7
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L6
                LDA     tab+16
                STA     _fcc_tmp_b
                DEC
                STA     tab+16
                LDA     _fcc_tmp_b
                TAX
                CMP     #1
                BNE     _symfold_L11
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                BEQ     _symfold_L10
_symfold_L11
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L10
                LDA     tab+16
                DEC
                STA     tab+16
                BMI     _symfold_L13
                LDA     tab+18
                STA     _fcc_tmp_b
                CLC
                ADC     #1
                STA     tab+18
                LDA     tab+18+2
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                AND     #$00FF
                BRA     _symfold_L14
_symfold_L13
                LDA     #$FFFF
_symfold_L14
                CMP     #$FFFF
                BEQ     _symfold_L12
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L12
                LDA     #2
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #120
                SEP     #$20
                MX      %10
                LDY     #14
                STA     [_fcc_fpr0],Y
                REP     #$20
                MX      %00
                LDA     tab+46
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     tab+46
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX
                CMP     #121
                BEQ     _symfold_L15
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L15
                LDA     #255
                AND     #$00FF
                SEP     #$20
                MX      %10
                STA     tab+46
                REP     #$20
                MX      %00
                LDA     tab+46
                AND     #$00FF
                INC
                SEP     #$20
                MX      %10
                STA     tab+46
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     _symfold_L16
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L16
                LDA     #2
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #4660
                LDY     #12
                STA     [_fcc_fpr0],Y
                LDA     #2
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #12
                LDA     [_fcc_fpr0],Y
                TAX
                CMP     #4660
                BEQ     _symfold_L17
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L17
                LDA     #3
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+16
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL take
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                TAX
                CMP     #10
                BEQ     _symfold_L18
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L18
                LDA     #1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                BPL     _symfold_L19
                LDA     #2
                BRA     _symfold_L20
_symfold_L19
                LDA     #1
_symfold_L20
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+16
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL take
                TAY
                TSC
                CLC
                ADC     #6
                TCS
                TYA
                STA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #9
                BEQ     _symfold_L21
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L21
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #14
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                BEQ     _symfold_L22
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L22
                LDA     1,S   ; fccstk d=0 b=1
                CMP     #0
                PHP
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab
                STA     _fcc_fpr0
                PLA
                PLP
                BPL     _symfold_L24
                LDA     #0
                BRA     _symfold_L25
_symfold_L24
                LDA     #1
_symfold_L25
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #14
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                TAX
                CMP     #7
                BEQ     _symfold_L23
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L23
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL addr
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+16
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL addr
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
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _symfold_L26
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L26
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+32
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+16
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                AND     #$00FF
                STA     _fcc_long_hi
                LDA     _fcc_fpr0
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                LDX     #16
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _symfold_L27
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L27
                LDA     #lg
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     1,S
                TAX
                TYA
                STA:    $0000,X
                LDA     _fcc_long_hi
                STA:    $0002,X
                PLA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #lg+4
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                LDX     #22136
                STX     _fcc_long_b_lo
                LDX     #4660
                STX     _fcc_long_b_hi
                JSR     _fcc_long_ne
                CMP     #0
                BEQ     _symfold_L28
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRL     main_bandx
_symfold_L28
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+32
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+16
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL below
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _symfold_L30
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #tab+16
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img16
                FGX2_FARCALL below
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _symfold_L29
_symfold_L30
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_symfold_L29
                LDA     #5
                SEP     #$20
                MX      %10
                STA     tab+14
                REP     #$20
                MX      %00
                LDA     #0
                ASL
                ASL
                ASL
                ASL
                CLC
                ADC     #tab
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #14
                LDA     [_fcc_fpr0],Y
                AND     #$00FF
                TAX
                CMP     #5
                BEQ     _symfold_L31
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                BRA     main_bandx
_symfold_L31
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
main_bandx
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     14
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 11
