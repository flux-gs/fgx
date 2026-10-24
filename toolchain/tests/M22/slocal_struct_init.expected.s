                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from slocal_struct_init.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT getpart
getpart            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #getpart_FRAMESIZE
                DO      getpart_STKGUARD
                BCC     getpart_stkovf
                CMP     _fcc_stkfloor
                BCS     getpart_stkok
getpart_stkovf       JMP     _fcc_stkoflow
                FIN
getpart_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     getpart_sl_p+2
                STA     _fcc_long_hi
                LDA     getpart_sl_p+0
                TAY
                LDA     _fcc_long_hi
                PHA
                TYA
                PHA
                LDA     getpart_sl_p+6
                STA     _fcc_long_hi
                LDA     getpart_sl_p+4
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
                TSC
                CLC
                ADC     #getpart_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
getpart_FRAMESIZE   EQU     0
getpart_STKGUARD    EQU     0
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
                LDA     main_sl_t+2
                STA     _fcc_long_hi
                LDA     main_sl_t+0
                TAX
                TXA
                CMP     #5
                BEQ     _slocal_struct_init_L0
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
_slocal_struct_init_L0
                LDA     main_sl_t+6
                STA     _fcc_long_hi
                LDA     main_sl_t+4
                TAX
                TXA
                CMP     #7
                BEQ     _slocal_struct_init_L1
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
_slocal_struct_init_L1
                FGX2_FARCALL getpart
                TAX
                TXA
                CMP     #9
                BEQ     _slocal_struct_init_L2
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
_slocal_struct_init_L2
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
main_FRAMESIZE   EQU     0
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 4
