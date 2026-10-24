                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from memsetbig.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _memsetbig_check
_memsetbig_check            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_memsetbig_check_FRAMESIZE
                DO      _memsetbig_check_STKGUARD
                BCC     _memsetbig_check_stkovf
                CMP     _fcc_stkfloor
                BCS     _memsetbig_check_stkok
_memsetbig_check_stkovf       JMP     _fcc_stkoflow
                FIN
_memsetbig_check_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_memsetbig_check_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_memsetbig_check_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_memsetbig_check_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
                DO      12+_memsetbig_check_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+_memsetbig_check_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+_memsetbig_check_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_img2
                DO      6+_memsetbig_check_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_memsetbig_check_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_memsetbig_check_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_img3
                DO      8+_memsetbig_check_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_memsetbig_check_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_memsetbig_check_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_img4
                LDA     #0
                STA     _fcc_img0
_memsetbig_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _memsetbig_L2
                LDA     _fcc_img4
                STA     _fcc_ptr+2
                LDA     _fcc_img3
                PHA
                LDA     _fcc_img0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     _fcc_img2
                AND     #$00FF
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BEQ     _memsetbig_L3
                LDA     #0
                TAY
                TSC
                CLC
                ADC     #_memsetbig_check_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memsetbig_L3
_memsetbig_L1
                INC     _fcc_img0
                BRA     _memsetbig_L0
_memsetbig_L2
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #_memsetbig_check_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memsetbig_check_FRAMESIZE   EQU     2
_memsetbig_check_STKGUARD    EQU     0
                FGX2_EXPORT _memsetbig_poison
_memsetbig_poison            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_memsetbig_poison_FRAMESIZE
                DO      _memsetbig_poison_STKGUARD
                BCC     _memsetbig_poison_stkovf
                CMP     _fcc_stkfloor
                BCS     _memsetbig_poison_stkok
_memsetbig_poison_stkovf       JMP     _fcc_stkoflow
                FIN
_memsetbig_poison_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      10+_memsetbig_poison_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+_memsetbig_poison_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+_memsetbig_poison_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_memsetbig_L4
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                LDA     _fcc_img1
                STA     _fcc_tmp_b
                TXA
                CMP     _fcc_tmp_b
                BCS     _memsetbig_L6
                DO      8+_memsetbig_poison_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_memsetbig_poison_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_memsetbig_poison_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_ptr+2
                DO      6+_memsetbig_poison_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_memsetbig_poison_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_memsetbig_poison_FRAMESIZE,S   ; fccstk d=0 b=6 fs
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
                LDA     #165
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
_memsetbig_L5
                INC     _fcc_img0
                BRA     _memsetbig_L4
_memsetbig_L6
                TAY
                TSC
                CLC
                ADC     #_memsetbig_poison_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_memsetbig_poison_FRAMESIZE   EQU     2
_memsetbig_poison_STKGUARD    EQU     0
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
                LDA     #40000
                LDX     #0
                STX     _fcc_long_hi
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #2
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
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL malloc
                TAY
                TSC
                CLC
                ADC     #4
                TCS
                TYA
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _memsetbig_L8
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _memsetbig_L8
                LDA     #1
                BRA     _memsetbig_L9
_memsetbig_L8
                LDA     #0
_memsetbig_L9
                CMP     #0
                BEQ     _memsetbig_L7
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
_memsetbig_L7
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_fpr0+2
                LDA     1,S   ; fccstk d=0 b=1
                STA     _fcc_fpr0
                LDA     #1
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     7,S   ; fccstk d=0 b=7
                LDA     _fcc_fpr0
                STA     5,S   ; fccstk d=0 b=5
                LDA     #40000
                TAX
                INC
                INC
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_poison
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #40000
                PHA
                LDA     #0
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                AND     #$00FF
                PHA
                LDA     #40000
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_check
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _memsetbig_L11
                LDA     #0
                BRA     _memsetbig_L12
_memsetbig_L11
                LDA     #1
_memsetbig_L12
                CMP     #0
                BEQ     _memsetbig_L10
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
_memsetbig_L10
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L14
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #40000
                TAX
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L14
                LDA     #0
                BRA     _memsetbig_L15
_memsetbig_L14
                LDA     #1
_memsetbig_L15
                CMP     #0
                BEQ     _memsetbig_L13
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
_memsetbig_L13
                LDA     #40000
                TAX
                INC
                INC
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_poison
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #40000
                PHA
                LDA     #92
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #92
                AND     #$00FF
                PHA
                LDA     #40000
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_check
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _memsetbig_L17
                LDA     #0
                BRA     _memsetbig_L18
_memsetbig_L17
                LDA     #1
_memsetbig_L18
                CMP     #0
                BEQ     _memsetbig_L16
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
_memsetbig_L16
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L20
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #40000
                TAX
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L20
                LDA     #0
                BRA     _memsetbig_L21
_memsetbig_L20
                LDA     #1
_memsetbig_L21
                CMP     #0
                BEQ     _memsetbig_L19
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
_memsetbig_L19
                LDA     #40000
                TAX
                INC
                INC
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_poison
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #32766
                PHA
                LDA     #0
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                AND     #$00FF
                PHA
                LDA     #32766
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_check
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _memsetbig_L25
                LDA     #0
                BRA     _memsetbig_L26
_memsetbig_L25
                LDA     #1
_memsetbig_L26
                CMP     #0
                BNE     _memsetbig_L23
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #32766
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L23
                LDA     #0
                BRA     _memsetbig_L24
_memsetbig_L23
                LDA     #1
_memsetbig_L24
                CMP     #0
                BEQ     _memsetbig_L22
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
_memsetbig_L22
                LDA     #40000
                TAX
                INC
                INC
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_poison
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #32766
                TAX
                INC
                PHA
                LDA     #0
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                AND     #$00FF
                PHA
                LDA     #32766
                TAX
                INC
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_check
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _memsetbig_L30
                LDA     #0
                BRA     _memsetbig_L31
_memsetbig_L30
                LDA     #1
_memsetbig_L31
                CMP     #0
                BNE     _memsetbig_L28
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #32766
                TAX
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L28
                LDA     #0
                BRA     _memsetbig_L29
_memsetbig_L28
                LDA     #1
_memsetbig_L29
                CMP     #0
                BEQ     _memsetbig_L27
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
_memsetbig_L27
                LDA     #40000
                TAX
                INC
                INC
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_poison
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #32766
                TAX
                INC
                INC
                PHA
                LDA     #0
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     #0
                AND     #$00FF
                PHA
                LDA     #32766
                TAX
                INC
                INC
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_check
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _memsetbig_L35
                LDA     #0
                BRA     _memsetbig_L36
_memsetbig_L35
                LDA     #1
_memsetbig_L36
                CMP     #0
                BNE     _memsetbig_L33
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #32766
                TAX
                INC
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L33
                LDA     #0
                BRA     _memsetbig_L34
_memsetbig_L33
                LDA     #1
_memsetbig_L34
                CMP     #0
                BEQ     _memsetbig_L32
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
_memsetbig_L32
                LDA     #40000
                TAX
                INC
                INC
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_poison
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                PHA
                LDA     #0
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL memset
                TSC
                CLC
                ADC     #8
                TCS
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_ptr+2
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BEQ     _memsetbig_L37
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
_memsetbig_L37
                LDA     #40000
                TAX
                INC
                INC
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_fpr0+2
                LDA     3,S   ; fccstk d=2 b=1
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_poison
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #40000
                PHA
                LDA     9,S   ; fccstk d=2 b=7
                STA     _fcc_fpr0+2
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL bzero
                TSC
                CLC
                ADC     #6
                TCS
                LDA     #0
                AND     #$00FF
                PHA
                LDA     #40000
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_fpr0+2
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _memsetbig_check
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                BEQ     _memsetbig_L39
                LDA     #0
                BRA     _memsetbig_L40
_memsetbig_L39
                LDA     #1
_memsetbig_L40
                CMP     #0
                BEQ     _memsetbig_L38
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
_memsetbig_L38
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L42
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_ptr+2
                LDA     1,S   ; fccstk d=0 b=1
                PHA
                LDA     #40000
                TAX
                INC
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                PHA
                LDA     #165
                AND     #$00FF
                STA     _fcc_tmp_b
                PLA
                CMP     _fcc_tmp_b
                BNE     _memsetbig_L42
                LDA     #0
                BRA     _memsetbig_L43
_memsetbig_L42
                LDA     #1
_memsetbig_L43
                CMP     #0
                BEQ     _memsetbig_L41
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
_memsetbig_L41
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
main_FRAMESIZE   EQU     8
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 25
