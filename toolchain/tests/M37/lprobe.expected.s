                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from lprobe.c
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #hstore
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     htab
                LDA     _fcc_fpr0+2
                STA     htab+2
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #cstore
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0
                STA     codetab
                LDA     _fcc_fpr0+2
                STA     codetab+2
                LDA     #0
                STA     15,S   ; fccstk d=0 b=15
                LDA     15,S   ; fccstk d=0 b=15
                STA     _fcc_img0
_lprobe_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                SEC
                SBC     #5010
                BVC     _lprobe_L3
                EOR     #$8000
_lprobe_L3
                BPL     _lprobe_L2
                SEP     #$20
                MX      %10
                LDA     htab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     htab
                PHA
                LDA     _fcc_img0
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
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$0001
                JSR     _fcc_long_neg
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
                SEP     #$20
                MX      %10
                LDA     codetab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     codetab
                PHA
                LDA     _fcc_img0
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
                LDA     #0
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
_lprobe_L1
                INC     _fcc_img0
                BRL     _lprobe_L0
_lprobe_L2
                LDA     _fcc_img0
                STA     15,S   ; fccstk d=0 b=15
                LDA     #5003
                STA     5,S   ; fccstk d=0 b=5
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     7,S   ; fccstk d=0 b=7
                TYA
                LDA     #$0006
                STA     _fcc_long_hi
                LDA     #$E065
                STA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                STA     13,S   ; fccstk d=0 b=13
                TYA
                SEP     #$20
                MX      %10
                LDA     htab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     htab
                PHA
                LDA     #200
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
                LDA     17,S   ; fccstk d=4 b=13
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=4 b=11
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
                SEP     #$20
                MX      %10
                LDA     codetab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     codetab
                PHA
                LDA     #200
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
                LDA     #77
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                LDA     #100
                STA     1,S   ; fccstk d=0 b=1
                TAY
                JSR     _fcc_long_from_int
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                LDA     7,S   ; fccstk d=0 b=7
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=0 b=5
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=4 b=1
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                STA     9,S   ; fccstk d=0 b=9
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
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
                BEQ     _lprobe_L4
                LDA     #1
                STA     9,S   ; fccstk d=0 b=9
_lprobe_L4
main_uL_probe
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     13,S   ; fccstk d=4 b=9
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_sub
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
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
                BEQ     _lprobe_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     11,S   ; fccstk d=4 b=7
                STA     _fcc_long_hi
                LDA     9,S   ; fccstk d=4 b=5
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_add
                STA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                STA     3,S   ; fccstk d=0 b=3
                TYA
_lprobe_L5
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #200
                JSR     _fcc_long_from_int
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
                BEQ     _lprobe_L6
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
_lprobe_L6
                LDA     13,S   ; fccstk d=0 b=13
                STA     _fcc_long_hi
                LDA     11,S   ; fccstk d=0 b=11
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     7,S   ; fccstk d=4 b=3
                STA     _fcc_long_hi
                LDA     5,S   ; fccstk d=4 b=1
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                FGX2_FARCALL htabof_eq
                TAY
                TSC
                CLC
                ADC     #8
                TCS
                TYA
                CMP     #0
                BNE     *+5
                BRL     _lprobe_L7
                LDA     3,S   ; fccstk d=0 b=3
                STA     _fcc_long_hi
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                TAX
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     codetab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     codetab
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDA     [_fcc_ptr]
                TAX
                CMP     #77
                BEQ     _lprobe_L8
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
_lprobe_L8
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     htab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     htab
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     17,S   ; fccstk d=4 b=13
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=4 b=11
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
                BEQ     _lprobe_L9
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
_lprobe_L9
                LDA     1,S   ; fccstk d=0 b=1
                ASL
                ASL
                TAX
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     htab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     htab
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     #0
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDX     _fcc_long_hi
                STX     _fcc_long_b_hi
                PLA
                TAY
                PLA
                STA     _fcc_long_hi
                TYA
                JSR     _fcc_long_les
                CMP     #0
                BEQ     _lprobe_L10
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
_lprobe_L10
                SEP     #$20
                MX      %10
                LDA     htab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     htab
                PHA
                LDA     3,S   ; fccstk d=2 b=1
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
                LDA     17,S   ; fccstk d=4 b=13
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=4 b=11
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
                SEP     #$20
                MX      %10
                LDA     codetab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     codetab
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_long_hi
                LDA     3,S   ; fccstk d=2 b=1
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
                LDA     #88
                TAY
                LDA     1,S
                STA     _fcc_ptr
                LDA     3,S
                STA     _fcc_ptr+2
                TYA
                STA     [_fcc_ptr]
                PLA
                PLA
                TYA
                LDA     #200
                ASL
                TAX
                LDA:    cstore,X
                TAX
                CMP     #88
                BEQ     _lprobe_L11
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
_lprobe_L11
                LDA     #200
                ASL
                ASL
                TAX
                LDA:    hstore+2,X
                STA     _fcc_long_hi
                LDA:    hstore,X
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     17,S   ; fccstk d=4 b=13
                STA     _fcc_long_hi
                LDA     15,S   ; fccstk d=4 b=11
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
                BEQ     _lprobe_L12
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
_lprobe_L12
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
_lprobe_L7
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
main_FRAMESIZE   EQU     16
main_STKGUARD    EQU     0
                FGX2_EXPORT htabof_eq
htabof_eq            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #htabof_eq_FRAMESIZE
                DO      htabof_eq_STKGUARD
                BCC     htabof_eq_stkovf
                CMP     _fcc_stkfloor
                BCS     htabof_eq_stkok
htabof_eq_stkovf       JMP     _fcc_stkoflow
                FIN
htabof_eq_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      8+htabof_eq_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+htabof_eq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+htabof_eq_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                DO      6+htabof_eq_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+htabof_eq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+htabof_eq_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                ASL
                ASL
                TAX
                STA     _fcc_tmp_b
                SEP     #$20
                MX      %10
                LDA     htab+2
                STA     _fcc_ptr+2
                REP     #$20
                MX      %00
                LDA     htab
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_ptr
                LDY     #2
                LDA     [_fcc_ptr],Y
                STA     _fcc_long_hi
                LDA     [_fcc_ptr]
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                DO      16+htabof_eq_FRAMESIZE/256
                TSC
                CLC
                ADC     #16+htabof_eq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     16+htabof_eq_FRAMESIZE,S   ; fccstk d=4 b=12 fs
                FIN
                STA     _fcc_long_hi
                DO      14+htabof_eq_FRAMESIZE/256
                TSC
                CLC
                ADC     #14+htabof_eq_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     14+htabof_eq_FRAMESIZE,S   ; fccstk d=4 b=10 fs
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
                TAY
                TSC
                CLC
                ADC     #htabof_eq_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
htabof_eq_FRAMESIZE   EQU     0
htabof_eq_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
