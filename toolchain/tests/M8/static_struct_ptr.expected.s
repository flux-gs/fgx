                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_struct_ptr.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT get
get            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #get_FRAMESIZE
                DO      get_STKGUARD
                BCC     get_stkovf
                CMP     _fcc_stkfloor
                BCS     get_stkok
get_stkovf       JMP     _fcc_stkoflow
                FIN
get_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                SEP     #$20
                MX      %10
                LDA     get_sl_dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     get_sl_dp
                STA     _fcc_fpr0
                LDA     #0
                STA     _fcc_fpr1
                STZ     _fcc_fpr1+2
                LDA     _fcc_fpr0
                CMP     _fcc_fpr1
                BEQ     *+5
                BRL     _static_struct_ptr_L1
                SEP     #$20
                MX      %10
                LDA     _fcc_fpr0+2
                CMP     _fcc_fpr1+2
                REP     #$20
                MX      %00
                BEQ     *+5
                BRL     _static_struct_ptr_L1
                LDA     #1
                BRL     _static_struct_ptr_L2
_static_struct_ptr_L1
                LDA     #0
_static_struct_ptr_L2
                CMP     #0
                BNE     *+5
                BRL     _static_struct_ptr_L0
                SEP     #$20
                MX      %10
                PHB
                PLA
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     #gd
                STA     _fcc_fpr0
                STA     get_sl_dp
                LDA     _fcc_fpr0+2
                STA     get_sl_dp+2
_static_struct_ptr_L0
                SEP     #$20
                MX      %10
                LDA     get_sl_dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     get_sl_dp
                STA     _fcc_fpr0
                LDA     #40
                STA     [_fcc_fpr0]
                SEP     #$20
                MX      %10
                LDA     get_sl_dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     get_sl_dp
                STA     _fcc_fpr0
                LDA     #2
                LDY     #2
                STA     [_fcc_fpr0],Y
                SEP     #$20
                MX      %10
                LDA     get_sl_dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     get_sl_dp
                STA     _fcc_fpr0
                LDA     [_fcc_fpr0]
                PHA
                SEP     #$20
                MX      %10
                LDA     get_sl_dp+2
                STA     _fcc_fpr0+2
                REP     #$20
                MX      %00
                LDA     get_sl_dp
                STA     _fcc_fpr0
                LDY     #2
                LDA     [_fcc_fpr0],Y
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #get_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
get_FRAMESIZE   EQU     0
get_STKGUARD    EQU     0
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
                FGX2_FARCALL get
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
