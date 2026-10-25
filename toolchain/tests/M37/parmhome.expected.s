                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from parmhome.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT touch
touch            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #touch_FRAMESIZE
                DO      touch_STKGUARD
                BCC     touch_stkovf
                CMP     _fcc_stkfloor
                BCS     touch_stkok
touch_stkovf       JMP     _fcc_stkoflow
                FIN
touch_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+touch_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+touch_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+touch_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+touch_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+touch_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+touch_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
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
                DO      14+touch_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+touch_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+touch_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                AND     #$00FF
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
                DO      8+touch_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+touch_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+touch_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+touch_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+touch_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+touch_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAY
                TSC
                CLC
                ADC     #touch_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
touch_FRAMESIZE   EQU     0
touch_STKGUARD    EQU     0
                FGX2_EXPORT kinds
kinds            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #kinds_FRAMESIZE
                DO      kinds_STKGUARD
                BCC     kinds_stkovf
                CMP     _fcc_stkfloor
                BCS     kinds_stkok
kinds_stkovf       JMP     _fcc_stkoflow
                FIN
kinds_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+kinds_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                DO      8+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+kinds_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     3,S   ; fccstk d=0 b=3
                DO      10+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+kinds_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     5,S   ; fccstk d=0 b=5
                DO      12+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+kinds_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     7,S   ; fccstk d=0 b=7
                DO      14+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+kinds_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     9,S   ; fccstk d=0 b=9
                DO      16+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+kinds_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
                STA     11,S   ; fccstk d=0 b=11
                DO      18+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+kinds_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     13,S   ; fccstk d=0 b=13
                DO      20+kinds_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+kinds_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+kinds_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     15,S   ; fccstk d=0 b=15
                LDA     #0
                STA     17,S   ; fccstk d=0 b=17
                LDA     #1
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL touch
                TSC
                CLC
                ADC     #6
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                TAX
                CMP     #120
                BNE     _parmhome_L1
                LDA     3,S   ; fccstk d=0 b=3
                CMP     #$FFFB
                BNE     _parmhome_L1
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
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
                BEQ     _parmhome_L0
_parmhome_L1
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #kinds_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_parmhome_L0
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                INC
                STA     1,S   ; fccstk d=0 b=1
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CLC
                ADC     #10
                STA     3,S   ; fccstk d=0 b=3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
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
                STA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #2
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL touch
                TSC
                CLC
                ADC     #6
                TCS
                LDA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                TAX
                CMP     #121
                BNE     _parmhome_L3
                LDA     3,S   ; fccstk d=0 b=3
                TAX
                CMP     #5
                BNE     _parmhome_L3
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1171
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
                BEQ     _parmhome_L2
_parmhome_L3
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #kinds_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_parmhome_L2
                LDA     17,S   ; fccstk d=0 b=17
                STA     _fcc_img0
_parmhome_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     9,S   ; fccstk d=0 b=9
                STA     _fcc_ptr
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     [_fcc_ptr]
                AND     #$00FF
                BEQ     _parmhome_L5
                LDA     _fcc_img0
                PHA
                LDA     13,S   ; fccstk d=2 b=11
                STA     _fcc_ptr+2
                LDA     11,S   ; fccstk d=2 b=9
                STA     _fcc_tmp_b
                INC
                STA     11,S   ; fccstk d=2 b=9
                LDA     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img0
                BRA     _parmhome_L4
_parmhome_L5
                LDA     _fcc_img0
                STA     17,S   ; fccstk d=0 b=17
                TAX
                LDA     #97
                TAY
                TYA
                CLC
                ADC     #98
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _parmhome_L7
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_ptr+2
                LDA     9,S   ; fccstk d=0 b=9
                PHA
                LDA     #$FFFF
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                CMP     #98
                BEQ     _parmhome_L6
_parmhome_L7
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #kinds_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_parmhome_L6
_parmhome_L8
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_ptr+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                DEC
                STA     [_fcc_ptr]
                BMI     _parmhome_L9
                LDA     17,S   ; fccstk d=0 b=17
                PHA
                LDA     17,S   ; fccstk d=2 b=15
                STA     _fcc_ptr+2
                LDA     15,S   ; fccstk d=2 b=13
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_tmp_b
                INC
                STA     [_fcc_ptr]
                LDY     #2
                LDA     [_fcc_ptr],Y
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
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     17,S   ; fccstk d=0 b=17
                BRA     _parmhome_L8
_parmhome_L9
                LDA     17,S   ; fccstk d=0 b=17
                TAX
                LDA     #97
                TAY
                TYA
                CLC
                ADC     #98
                TAY
                TYA
                CLC
                ADC     #99
                TAY
                TYA
                CLC
                ADC     #100
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BNE     _parmhome_L11
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                CMP     #$FFFF
                BEQ     _parmhome_L10
_parmhome_L11
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #kinds_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_parmhome_L10
                LDA     #0
                STA     13,S   ; fccstk d=0 b=13
                LDA     #0
                STA     15,S   ; fccstk d=0 b=15
                LDA     #3
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #18
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL touch
                TSC
                CLC
                ADC     #6
                TCS
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_fpr0+2
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _parmhome_L14
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _parmhome_L14
                LDA     #1
                BRA     _parmhome_L15
_parmhome_L14
                LDA     #0
_parmhome_L15
                CMP     #0
                BEQ     _parmhome_L12
                LDA     #0
                BRA     _parmhome_L13
_parmhome_L12
                LDA     #5
_parmhome_L13
                TAY
                TSC
                CLC
                ADC     #kinds_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
kinds_FRAMESIZE   EQU     318
kinds_STKGUARD    EQU     1
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
                LDA     #4
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL touch
                TSC
                CLC
                ADC     #6
                TCS
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                TSC
                CLC
                ADC     #6+addr_FRAMESIZE
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_ptr+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #2
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #2
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #2
                INC
                PHA
                LDA     #1
                EOR     #$FFFF
                STA     _fcc_tmp_b
                PLA
                AND     _fcc_tmp_b
                STA     _fcc_tmp_b
                LDA     _fcc_fpr0
                SEC
                SBC     _fcc_tmp_b
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                STA     5,S   ; fccstk d=0 b=5
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     5,S   ; fccstk d=0 b=5
                TAX
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
                STA     _fcc_tmp_b
                TXA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #addr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
addr_FRAMESIZE   EQU     306
addr_STKGUARD    EQU     1
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
                SEP     #$20
                MX      %10
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                PHA
                LDA     #0
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #99
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
                ADC     #6
                PHA
                LDA     #1
                CLC
                ADC     1,S
                TAY
                PLA
                TYA
                PHA
                LDA     #100
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
                ADC     #6
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
                LDA     #2
                STA     1,S   ; fccstk d=0 b=1
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     _fcc_fpr0
                STA     _fcc_tmp_b
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_ptr+2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_tmp_b
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
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_parmhome_S0
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$1170
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$FFFB
                PHA
                LDA     #120
                PHA
                FGX2_FARCALL kinds
                TAY
                TSC
                CLC
                ADC     #16
                TCS
                TYA
                STA     11,S   ; fccstk d=0 b=11
                BEQ     _parmhome_L16
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_parmhome_L16
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr1+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #6
                STA     _fcc_fpr1
                LDA     #2
                CLC
                ADC     _fcc_fpr1
                STA     _fcc_fpr1
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _parmhome_L18
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _parmhome_L18
                LDA     #0
                BRA     _parmhome_L19
_parmhome_L18
                LDA     #1
_parmhome_L19
                CMP     #0
                BEQ     _parmhome_L17
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
_parmhome_L17
                LDA     #36
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL addr
                TAY
                PLA
                PLA
                TYA
                TAX
                CMP     #37
                BEQ     _parmhome_L20
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
_parmhome_L20
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
main_FRAMESIZE   EQU     12
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 11
