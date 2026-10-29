                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from ldouble_store.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _ldouble_store_put
_ldouble_store_put            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_store_put_FRAMESIZE
                DO      _ldouble_store_put_STKGUARD
                BCC     _ldouble_store_put_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_store_put_stkok
_ldouble_store_put_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_store_put_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ldouble_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ldouble_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ldouble_store_put_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_ldouble_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ldouble_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ldouble_store_put_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #0
                ASL
                ASL
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
                DO      20+_ldouble_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_ldouble_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_ldouble_store_put_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_ldouble_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_ldouble_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_ldouble_store_put_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #1
                ASL
                ASL
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
                DO      16+_ldouble_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ldouble_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ldouble_store_put_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_ldouble_store_put_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ldouble_store_put_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ldouble_store_put_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
                STA     _fcc_tmp_b
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                LDA     _fcc_tmp_b
                STA     [_fcc_ptr]
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_ptr],Y
                PLA
                PLA
                TAY
                TSC
                CLC
                ADC     #_ldouble_store_put_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_store_put_FRAMESIZE   EQU     4
_ldouble_store_put_STKGUARD    EQU     0
                FGX2_EXPORT _ldouble_store_is
_ldouble_store_is            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_ldouble_store_is_FRAMESIZE
                DO      _ldouble_store_is_STKGUARD
                BCC     _ldouble_store_is_stkovf
                CMP     _fcc_stkfloor
                BCS     _ldouble_store_is_stkok
_ldouble_store_is_stkovf       JMP     _fcc_stkoflow
                FIN
_ldouble_store_is_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+_ldouble_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+_ldouble_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+_ldouble_store_is_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+_ldouble_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_ldouble_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_ldouble_store_is_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img1
                LDA     _fcc_fpr0
                STA     _fcc_img0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      20+_ldouble_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+_ldouble_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+_ldouble_store_is_FRAMESIZE,S   ; fccstk d=4 b=16 fs
                FIN
                STA     _fcc_long_hi
                DO      18+_ldouble_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+_ldouble_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+_ldouble_store_is_FRAMESIZE,S   ; fccstk d=4 b=14 fs
                FIN
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
                BEQ     _ldouble_store_L0
                LDA     _fcc_img1
                STA     _fcc_ptr+2
                LDA     _fcc_img0
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                STA     _fcc_long_b_lo
                LDA     _fcc_ptr
                INC
                INC
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                STA     _fcc_long_hi
                LDA     _fcc_long_b_lo
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+_ldouble_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+_ldouble_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+_ldouble_store_is_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+_ldouble_store_is_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+_ldouble_store_is_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+_ldouble_store_is_FRAMESIZE,S   ; fccstk d=4 b=10 fs
                FIN
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
                BEQ     _ldouble_store_L0
                LDA     #1
                BRA     _ldouble_store_L1
_ldouble_store_L0
                LDA     #0
_ldouble_store_L1
                TAY
                TSC
                CLC
                ADC     #_ldouble_store_is_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_ldouble_store_is_FRAMESIZE   EQU     4
_ldouble_store_is_STKGUARD    EQU     0
                FGX2_EXPORT ident
ident            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #ident_FRAMESIZE
                DO      ident_STKGUARD
                BCC     ident_stkovf
                CMP     _fcc_stkfloor
                BCS     ident_stkok
ident_stkovf       JMP     _fcc_stkoflow
                FIN
ident_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+ident_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+ident_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+ident_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+ident_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+ident_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+ident_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+ident_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+ident_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+ident_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+ident_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+ident_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+ident_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                TAY
                TSC
                CLC
                ADC     #ident_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
ident_FRAMESIZE   EQU     0
ident_STKGUARD    EQU     0
                FGX2_EXPORT kr
kr            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #kr_FRAMESIZE
                DO      kr_STKGUARD
                BCC     kr_stkovf
                CMP     _fcc_stkfloor
                BCS     kr_stkok
kr_stkovf       JMP     _fcc_stkoflow
                FIN
kr_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      12+kr_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+kr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+kr_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q3
                DO      10+kr_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+kr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+kr_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_q2
                DO      8+kr_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+kr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+kr_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_long_hi
                DO      6+kr_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+kr_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+kr_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                TSC
                CLC
                ADC     #kr_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
kr_FRAMESIZE   EQU     8
kr_STKGUARD    EQU     0
                FGX2_EXPORT pick
pick            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pick_FRAMESIZE
                DO      pick_STKGUARD
                BCC     pick_stkovf
                CMP     _fcc_stkfloor
                BCS     pick_stkok
pick_stkovf       JMP     _fcc_stkoflow
                FIN
pick_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pick_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                CMP     #0
                BEQ     _ldouble_store_L2
                DO      14+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+pick_FRAMESIZE,S   ; fccstk d=0 b=14 fs
                FIN
                STA     _fcc_q3
                DO      12+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #12+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     12+pick_FRAMESIZE,S   ; fccstk d=0 b=12 fs
                FIN
                STA     _fcc_q2
                DO      10+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #10+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     10+pick_FRAMESIZE,S   ; fccstk d=0 b=10 fs
                FIN
                STA     _fcc_long_hi
                DO      8+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+pick_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                BRA     _ldouble_store_L3
_ldouble_store_L2
                DO      22+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #22+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     22+pick_FRAMESIZE,S   ; fccstk d=0 b=22 fs
                FIN
                STA     _fcc_q3
                DO      20+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #20+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     20+pick_FRAMESIZE,S   ; fccstk d=0 b=20 fs
                FIN
                STA     _fcc_q2
                DO      18+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #18+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     18+pick_FRAMESIZE,S   ; fccstk d=0 b=18 fs
                FIN
                STA     _fcc_long_hi
                DO      16+pick_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+pick_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+pick_FRAMESIZE,S   ; fccstk d=0 b=16 fs
                FIN
_ldouble_store_L3
                TAY
                TSC
                CLC
                ADC     #pick_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pick_FRAMESIZE   EQU     0
pick_STKGUARD    EQU     0
                FGX2_EXPORT main
main            ENT
                PEI     _fcc_fb
                PEI     _fcc_img16
                PEI     _fcc_img17
                PEI     _fcc_img18
                PEI     _fcc_img19
                TSC
                SEC
                SBC     #main_FRAMESIZE-8
                DO      main_STKGUARD
                BCC     main_stkovf
                CMP     _fcc_stkfloor
                BCS     main_stkok
main_stkovf       JMP     _fcc_stkoflow
                FIN
main_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #1
                STA     71,S   ; fccstk d=0 b=71
                LDA     #0
                STA     _fcc_q3
                STA     _fcc_q2
                STA     _fcc_long_hi
                STA     _fcc_tmp_b
                STA     73,S   ; fccstk d=0 b=73
                LDA     _fcc_long_hi
                STA     75,S   ; fccstk d=0 b=75
                LDA     _fcc_q2
                STA     77,S   ; fccstk d=0 b=77
                LDA     _fcc_q3
                STA     79,S   ; fccstk d=0 b=79
                LDA     #0
                STA     81,S   ; fccstk d=0 b=81
                LDA     #1
                STA     25,S   ; fccstk d=0 b=25
                LDA     #8
                TAX
                CMP     #8
                BNE     _ldouble_store_L5
                LDA     #8
                TAX
                CMP     #8
                BNE     _ldouble_store_L5
                LDA     #32
                TAX
                CMP     #32
                BEQ     _ldouble_store_L4
_ldouble_store_L5
                LDA     #1
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L4
                LDA     #12
                TAX
                CMP     #12
                BNE     _ldouble_store_L7
                LDA     #8
                TAX
                CMP     #8
                BEQ     _ldouble_store_L6
_ldouble_store_L7
                LDA     #2
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L6
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_q3
                LDA     5,S   ; fccstk d=0 b=5
                STA     _fcc_q2
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                STA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_long_hi
                STA     11,S   ; fccstk d=0 b=11
                LDA     _fcc_q2
                STA     13,S   ; fccstk d=0 b=13
                LDA     _fcc_q3
                STA     15,S   ; fccstk d=0 b=15
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L8
                LDA     #3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L8
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                STA     g
                TAY
                LDA     _fcc_long_hi
                STA     g+2
                LDA     _fcc_q2
                STA     g+4
                LDA     _fcc_q3
                STA     g+6
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
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
                LDA     #g
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L9
                LDA     #4
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L9
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_put
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L10
                LDA     #5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L10
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #26
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #26
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L11
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L11
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #26
                STA     _fcc_fpr0
                LDA     25,S   ; fccstk d=0 b=25
                TAX
                INC
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L12
                LDA     #7
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L12
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #garr+8
                STA     _fcc_fpr0
                PLA
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
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
                LDA     #garr+8
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L13
                LDA     #8
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L13
                LDA     25,S   ; fccstk d=0 b=25
                ASL
                ASL
                ASL
                CLC
                ADC     #garr
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L14
                LDA     #9
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L14
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #26
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                LDY     #0
                STA     [_fcc_img16],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_img16],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_img16],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_img16],Y
                TXA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #26
                CLC
                ADC     #8
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L15
                LDA     #10
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L15
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                CLC
                ADC     #8
                STA     _fcc_fpr0
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #26
                CLC
                ADC     #16
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L16
                LDA     #11
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L16
                LDA     _fcc_img17
                STA     _fcc_fpr0+2
                LDA     _fcc_img16
                STA     _fcc_fpr0
                LDA     25,S   ; fccstk d=0 b=25
                ASL
                ASL
                ASL
                CLC
                ADC     _fcc_fpr0
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_fpr0],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_fpr0],Y
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L17
                LDA     #12
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L17
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #garr
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     gp
                LDA     _fcc_fpr0+2
                STA     gp+2
                SEP     #$20
                MX      %10
                LDA     gp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     gp
                CLC
                ADC     #16
                STA     _fcc_fpr0
                LDY     #6
                LDA     [_fcc_img16],Y
                STA     _fcc_q3
                LDY     #4
                LDA     [_fcc_img16],Y
                STA     _fcc_q2
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_long_hi
                LDY     #0
                LDA     [_fcc_img16],Y
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
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
                LDA     #garr+16
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L18
                LDA     #13
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L18
                LDA     #7
                STA     59,S   ; fccstk d=0 b=59
                LDA     #9
                STA     69,S   ; fccstk d=0 b=69
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #58
                INC
                INC
                STA     _fcc_fpr0
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #58
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L19
                LDA     #14
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L19
                LDA     59,S   ; fccstk d=0 b=59
                TAX
                CMP     #7
                BNE     _ldouble_store_L21
                LDA     69,S   ; fccstk d=0 b=69
                TAX
                CMP     #9
                BEQ     _ldouble_store_L20
_ldouble_store_L21
                LDA     #15
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L20
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img19
                LDA     _fcc_fpr0
                STA     _fcc_img18
                LDA     _fcc_img19
                STA     _fcc_fpr0+2
                LDA     _fcc_img18
                INC
                INC
                STA     _fcc_fpr0
                LDA     67,S   ; fccstk d=0 b=67
                STA     _fcc_q3
                LDA     65,S   ; fccstk d=0 b=65
                STA     _fcc_q2
                LDA     63,S   ; fccstk d=0 b=63
                STA     _fcc_long_hi
                LDA     61,S   ; fccstk d=0 b=61
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
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
                LDA     #gs+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                CMP     #0
                BNE     _ldouble_store_L22
                LDA     #16
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L22
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gs2
                STA     _fcc_fpr0
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr0+2
                LDA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     #gs
                STA     _fcc_fpr1
                JSR     _fcc_bank_from_carrier
                STA     _fcc_fpr1+2
                LDA     _fcc_fpr1
                LDY     #10
_ldouble_store_L23
                LDA     [_fcc_fpr1],Y
                STA     [_fcc_fpr0],Y
                DEY
                DEY
                BPL     _ldouble_store_L23
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
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
                LDA     #gs2+2
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L24
                LDA     #17
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L24
                LDY     #8
                LDA     [_fcc_img18],Y
                STA     _fcc_q3
                LDY     #6
                LDA     [_fcc_img18],Y
                STA     _fcc_q2
                LDY     #4
                LDA     [_fcc_img18],Y
                STA     _fcc_long_hi
                LDY     #2
                LDA     [_fcc_img18],Y
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L25
                LDA     #18
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L25
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL ident
                PLY
                PLY
                PLY
                PLY
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L26
                LDA     #19
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L26
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL kr
                PLY
                PLY
                PLY
                PLY
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L27
                LDA     #20
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L27
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #1
                PHA
                FGX2_FARCALL pick
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L28
                LDA     #21
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L28
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                TAY
                LDA     _fcc_q3
                PHA
                LDA     _fcc_q2
                PHA
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL pick
                TAY
                TSC
                CLC
                ADC     #18
                TCS
                TYA
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L29
                LDA     #22
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L29
                LDA     25,S   ; fccstk d=0 b=25
                BEQ     _ldouble_store_L30
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_q3
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_q2
                LDA     11,S   ; fccstk d=0 b=11
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=0 b=9
                BRA     _ldouble_store_L31
_ldouble_store_L30
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
_ldouble_store_L31
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$1234
                STA     _fcc_long_hi
                LDA     #$5678
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$C0FE
                STA     _fcc_long_hi
                LDA     #$2400
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L32
                LDA     #23
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L32
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L33
                LDA     #24
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRL     main_bandx
_ldouble_store_L33
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #58
                INC
                INC
                STA     _fcc_fpr0
                LDA     g+6
                STA     _fcc_q3
                LDA     g+4
                STA     _fcc_q2
                LDA     g+2
                STA     _fcc_long_hi
                LDA     g
                LDY     #0
                STA     [_fcc_fpr0],Y
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q2
                LDY     #4
                STA     [_fcc_fpr0],Y
                LDA     _fcc_q3
                LDY     #6
                STA     [_fcc_fpr0],Y
                TXA
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_q2
                STA     5,S   ; fccstk d=0 b=5
                LDA     _fcc_q3
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
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
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _ldouble_store_L35
                LDA     #$51EB
                STA     _fcc_long_hi
                LDA     #$851F
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #$4009
                STA     _fcc_long_hi
                LDA     #$1EB8
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #58
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BNE     _ldouble_store_L34
_ldouble_store_L35
                LDA     #25
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRA     main_bandx
_ldouble_store_L34
                LDA     71,S   ; fccstk d=0 b=71
                TAX
                CMP     #1
                BNE     _ldouble_store_L37
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0000
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
                SEP     #$20
                MX      %10
                LDA     #0
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     _fcc_fb
                CLC
                ADC     #70
                INC
                INC
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL _ldouble_store_is
                TAY
                TSC
                CLC
                ADC     #12
                TCS
                TYA
                BEQ     _ldouble_store_L37
                LDA     81,S   ; fccstk d=0 b=81
                BEQ     _ldouble_store_L36
_ldouble_store_L37
                LDA     #26
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
                BRA     main_bandx
_ldouble_store_L36
                LDA     #42
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-8
                TCS
main_bandx
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
main_FRAMESIZE   EQU     90
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 37
