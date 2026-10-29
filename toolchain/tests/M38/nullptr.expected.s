                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from nullptr.c
;---------------------------------------

                MX      %00
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
                STA     _fcc_fpr0+2
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
                STA     _fcc_fpr0
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
                SEP     #$20
                MX      %10
                LDA     pick_sl_cached+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pick_sl_cached
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _nullptr_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _nullptr_L1
                LDA     #1
                BRA     _nullptr_L2
_nullptr_L1
                LDA     #0
_nullptr_L2
                CMP     #0
                BEQ     _nullptr_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #_nullptr_S2
                STA     _fcc_fpr0
                STA     pick_sl_cached
                LDA     _fcc_fpr0+2
                STA     pick_sl_cached+2
_nullptr_L0
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
                BEQ     _nullptr_L3
                SEP     #$20
                MX      %10
                LDA     pick_sl_cached+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     pick_sl_cached
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ident
                PLY
                PLY
                BRA     _nullptr_L4
_nullptr_L3
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
_nullptr_L4
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
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    _nullptr_tab+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    _nullptr_tab,X
                STA     _fcc_fpr0
                LDA     _fcc_fpr0+2
                AND     #$00FF
                ORA     _fcc_fpr0
                BEQ     _nullptr_L5
                LDA     #1
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    _nullptr_tab+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    _nullptr_tab,X
                STA     _fcc_fpr0
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ident
                PLY
                PLY
                BRA     _nullptr_L6
_nullptr_L5
                LDA     #0
                STA     _fcc_fpr0
                STZ     _fcc_fpr0+2
_nullptr_L6
                PEI     _fcc_fpr0+2
                PEI     _fcc_fpr0
                FGX2_FARCALL ident
                PLY
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
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
                TAX
                LDA     #98
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_ptr+2
                LDA     3,S   ; fccstk d=2 b=1
                PHA
                LDA     #1
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #98
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                LDA     #1
                PHA
                FGX2_FARCALL pick
                PLY
                LDA     _fcc_fpr0+2
                STA     3,S   ; fccstk d=0 b=3
                LDA     _fcc_fpr0
                STA     1,S   ; fccstk d=0 b=1
                LDA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     5,S   ; fccstk d=2 b=3
                STA     _fcc_ptr+2
                LDA     3,S   ; fccstk d=2 b=1
                PHA
                LDA     #0
                CLC
                ADC     1,S
                STA     _fcc_ptr
                PLA
                LDA     [_fcc_ptr]
                AND     #$00FF
                TAX
                LDA     #122
                STA     _fcc_tmp_b
                TXA
                JSR     _fcc_eq16
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #0
                PHA
                FGX2_FARCALL pick
                PLY
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _nullptr_L7
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _nullptr_L7
                LDA     #1
                BRA     _nullptr_L8
_nullptr_L7
                LDA     #0
_nullptr_L8
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
                PHA
                LDA     #2
                ASL
                ASL
                TAX
                SEP     #$20
                MX      %10
                LDA:    _nullptr_tab+2,X
                STA     _fcc_fpr0+2
                STZ     _fcc_fpr0+3
                REP     #$20
                MX      %00
                LDA:    _nullptr_tab,X
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BNE     _nullptr_L9
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BNE     _nullptr_L9
                LDA     #1
                BRA     _nullptr_L10
_nullptr_L9
                LDA     #0
_nullptr_L10
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     5,S   ; fccstk d=0 b=5
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
                FGX2_RELOC_COUNT 9
