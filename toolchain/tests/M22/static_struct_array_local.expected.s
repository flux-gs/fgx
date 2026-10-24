                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_struct_array_local.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT _static_struct_array_local_sized
_static_struct_array_local_sized            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_static_struct_array_local_sized_FRAMESIZE
                DO      _static_struct_array_local_sized_STKGUARD
                BCC     _static_struct_array_local_sized_stkovf
                CMP     _fcc_stkfloor
                BCS     _static_struct_array_local_sized_stkok
_static_struct_array_local_sized_stkovf       JMP     _fcc_stkoflow
                FIN
_static_struct_array_local_sized_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #_static_struct_array_local_sized_sl_a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDA     #0
                ASL
                ASL
                CLC
                ADC     #_static_struct_array_local_sized_sl_a
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
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #_static_struct_array_local_sized_sl_a
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #1
                ASL
                ASL
                CLC
                ADC     #_static_struct_array_local_sized_sl_a
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
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #_static_struct_array_local_sized_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_static_struct_array_local_sized_FRAMESIZE   EQU     0
_static_struct_array_local_sized_STKGUARD    EQU     0
                FGX2_EXPORT _static_struct_array_local_from_init
_static_struct_array_local_from_init            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_static_struct_array_local_from_init_FRAMESIZE
                DO      _static_struct_array_local_from_init_STKGUARD
                BCC     _static_struct_array_local_from_init_stkovf
                CMP     _fcc_stkfloor
                BCS     _static_struct_array_local_from_init_stkok
_static_struct_array_local_from_init_stkovf       JMP     _fcc_stkoflow
                FIN
_static_struct_array_local_from_init_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #0
                STA     _fcc_img1
                LDA     #0
                STA     _fcc_img0
_static_struct_array_local_L0
                LDAL    KFGX_YIELD_MIRROR
                BEQ     *+5
                JSR     _fcc_safepoint
                LDA     _fcc_img0
                TAX
                TXA
                SEC
                SBC     #3
                BVC     _static_struct_array_local_L3
                EOR     #$8000
_static_struct_array_local_L3
                BPL     _static_struct_array_local_L2
                LDA     _fcc_img1
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     #_static_struct_array_local_from_init_sl_b
                STA     _fcc_fpr0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     [_fcc_fpr0]
                PHA
                LDA     _fcc_img0
                ASL
                ASL
                CLC
                ADC     #_static_struct_array_local_from_init_sl_b
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
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                STA     _fcc_img1
_static_struct_array_local_L1
                INC     _fcc_img0
                BRA     _static_struct_array_local_L0
_static_struct_array_local_L2
                LDA     _fcc_img1
                TAY
                TSC
                CLC
                ADC     #_static_struct_array_local_from_init_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_static_struct_array_local_from_init_FRAMESIZE   EQU     4
_static_struct_array_local_from_init_STKGUARD    EQU     0
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
                STA     1,S   ; fccstk d=0 b=1
                FGX2_FARCALL _static_struct_array_local_sized
                TAX
                TXA
                CMP     #10
                BNE     _static_struct_array_local_L4
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #21
                STA     1,S   ; fccstk d=0 b=1
_static_struct_array_local_L4
                FGX2_FARCALL _static_struct_array_local_from_init
                TAX
                TXA
                CMP     #45
                BNE     _static_struct_array_local_L5
                LDA     1,S   ; fccstk d=0 b=1
                TAX
                TXA
                CLC
                ADC     #21
                STA     1,S   ; fccstk d=0 b=1
_static_struct_array_local_L5
                LDA     1,S   ; fccstk d=0 b=1
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
                FGX2_RELOC_COUNT 6
