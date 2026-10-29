                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from deref_long_rmw.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT pop
pop            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #pop_FRAMESIZE
                DO      pop_STKGUARD
                BCC     pop_stkovf
                CMP     _fcc_stkfloor
                BCS     pop_stkok
pop_stkovf       JMP     _fcc_stkoflow
                FIN
pop_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                DO      8+pop_FRAMESIZE/256
                TSC
                CLC
                ADC     #8+pop_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     8+pop_FRAMESIZE,S   ; fccstk d=0 b=8 fs
                FIN
                STA     _fcc_fpr0+2
                DO      6+pop_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+pop_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+pop_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_long_hi
                LDA     [_fcc_fpr0]
                JSR     _fcc_long_add
                STA     [_fcc_fpr0]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_fpr0],Y
                TXA
                TAY
                TSC
                CLC
                ADC     #pop_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
pop_FRAMESIZE   EQU     0
pop_STKGUARD    EQU     0
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
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_v
                STA     _fcc_fpr0
                PLA
                LDA     _fcc_fpr0+2
                STA     _fcc_img17
                LDA     _fcc_fpr0
                STA     _fcc_img16
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     g_v
                TAY
                LDA     _fcc_long_hi
                STA     g_v+2
                TYA
                LDA     #$FFFF
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_long_hi
                LDA     [_fcc_img16]
                JSR     _fcc_long_add
                STA     [_fcc_img16]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_img16],Y
                TXA
                LDA     g_v+2
                STA     _fcc_long_hi
                LDA     g_v
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _deref_long_rmw_L0
                LDA     #14
                BRA     _deref_long_rmw_L1
_deref_long_rmw_L0
                LDA     #0
_deref_long_rmw_L1
                STA     5,S   ; fccstk d=0 b=5
                LDA     #$0000
                STA     _fcc_long_hi
                LDA     #$FFFF
                STA     g_v
                TAY
                LDA     _fcc_long_hi
                STA     g_v+2
                TYA
                LDA     #1
                JSR     _fcc_long_from_int
                STA     _fcc_long_b_lo
                LDA     _fcc_long_hi
                STA     _fcc_long_b_hi
                LDY     #2
                LDA     [_fcc_img16],Y
                STA     _fcc_long_hi
                LDA     [_fcc_img16]
                JSR     _fcc_long_add
                STA     [_fcc_img16]
                TAX
                LDA     _fcc_long_hi
                LDY     #2
                STA     [_fcc_img16],Y
                TXA
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     g_v+2
                STA     _fcc_long_hi
                LDA     g_v
                LDX     #0
                STX     _fcc_long_b_lo
                LDX     #1
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _deref_long_rmw_L2
                LDA     #14
                BRA     _deref_long_rmw_L3
_deref_long_rmw_L2
                LDA     #0
_deref_long_rmw_L3
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     #$0001
                STA     _fcc_long_hi
                LDA     #$0000
                STA     g_v
                TAY
                LDA     _fcc_long_hi
                STA     g_v+2
                TYA
                PHA
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #g_v
                STA     _fcc_fpr0
                PLA
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL pop
                PLY
                PLY
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     g_v+2
                STA     _fcc_long_hi
                LDA     g_v
                LDX     #65535
                STX     _fcc_long_b_lo
                LDX     #0
                STX     _fcc_long_b_hi
                JSR     _fcc_long_eq
                CMP     #0
                BEQ     _deref_long_rmw_L4
                LDA     #14
                BRA     _deref_long_rmw_L5
_deref_long_rmw_L4
                LDA     #0
_deref_long_rmw_L5
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE-4
                TCS
                PLA
                STA     _fcc_img17
                PLA
                STA     _fcc_img16
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     10
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
