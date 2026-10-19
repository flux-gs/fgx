                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from aud_cast_sizeof.c
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
                LDA     #4138
                STA     1,S   ; fccstk d=0 b=1
                AND     #$00FF
                STA     3,S   ; fccstk d=0 b=3
                LDA     #2
                STA     5,S   ; fccstk d=0 b=5
                LDA     3,S   ; fccstk d=0 b=3
                PHA
                LDA     7,S   ; fccstk d=2 b=5
                STA     _fcc_tmp_b
                PLA
                JSR     _fcc_mul16
                CMP     #$8000
                BCC     _aud_cast_sizeof_L0
                CLC
                ADC     #1
_aud_cast_sizeof_L0
                CMP     #$8000
                ROR
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
                FGX2_RELOC_COUNT 2
