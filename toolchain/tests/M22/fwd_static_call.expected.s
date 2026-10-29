                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from fwd_static_call.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT early
early            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #early_FRAMESIZE
                DO      early_STKGUARD
                BCC     early_stkovf
                CMP     _fcc_stkfloor
                BCS     early_stkok
early_stkovf       JMP     _fcc_stkoflow
                FIN
early_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #3
                PHA
                FGX2_FARCALL _fwd_static_call_helper
                PLY
                PHA
                FGX2_FARCALL _fwd_static_call_tail
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                TAY
                TSC
                CLC
                ADC     #early_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
early_FRAMESIZE   EQU     0
early_STKGUARD    EQU     0
                FGX2_EXPORT _fwd_static_call_helper
_fwd_static_call_helper            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fwd_static_call_helper_FRAMESIZE
                DO      _fwd_static_call_helper_STKGUARD
                BCC     _fwd_static_call_helper_stkovf
                CMP     _fcc_stkfloor
                BCS     _fwd_static_call_helper_stkok
_fwd_static_call_helper_stkovf       JMP     _fcc_stkoflow
                FIN
_fwd_static_call_helper_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                DO      6+_fwd_static_call_helper_FRAMESIZE/256
                TSC
                CLC
                ADC     #6+_fwd_static_call_helper_FRAMESIZE
                STA     _fcc_fp
                STZ     _fcc_fp+2
                LDA     [_fcc_fp]
                ELSE
                LDA     6+_fwd_static_call_helper_FRAMESIZE,S   ; fccstk d=0 b=6 fs
                FIN
                STA     _fcc_tmp_b
                ASL
                CLC
                ADC     _fcc_tmp_b
                ASL
                ASL
                TAY
                TSC
                CLC
                ADC     #_fwd_static_call_helper_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fwd_static_call_helper_FRAMESIZE   EQU     0
_fwd_static_call_helper_STKGUARD    EQU     0
                FGX2_EXPORT _fwd_static_call_tail
_fwd_static_call_tail            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fwd_static_call_tail_FRAMESIZE
                DO      _fwd_static_call_tail_STKGUARD
                BCC     _fwd_static_call_tail_stkovf
                CMP     _fcc_stkfloor
                BCS     _fwd_static_call_tail_stkok
_fwd_static_call_tail_stkovf       JMP     _fcc_stkoflow
                FIN
_fwd_static_call_tail_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                FGX2_FARCALL _fwd_static_call_again
                TAY
                TSC
                CLC
                ADC     #_fwd_static_call_tail_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fwd_static_call_tail_FRAMESIZE   EQU     0
_fwd_static_call_tail_STKGUARD    EQU     0
                FGX2_EXPORT _fwd_static_call_again
_fwd_static_call_again            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #_fwd_static_call_again_FRAMESIZE
                DO      _fwd_static_call_again_STKGUARD
                BCC     _fwd_static_call_again_stkovf
                CMP     _fcc_stkfloor
                BCS     _fwd_static_call_again_stkok
_fwd_static_call_again_stkovf       JMP     _fcc_stkoflow
                FIN
_fwd_static_call_again_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     #6
                TAY
                TSC
                CLC
                ADC     #_fwd_static_call_again_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
_fwd_static_call_again_FRAMESIZE   EQU     0
_fwd_static_call_again_STKGUARD    EQU     0
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
                FGX2_FARCALL early
                STA     1,S   ; fccstk d=0 b=1
                LDA     #0
                PHA
                FGX2_FARCALL _fwd_static_call_helper
                PLY
                STA     3,S   ; fccstk d=0 b=3
                LDA     1,S   ; fccstk d=0 b=1
                CLC
                ADC     3,S   ; fccstk d=0 b=3
                TAY
                TSC
                CLC
                ADC     #main_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
main_FRAMESIZE   EQU     4
main_STKGUARD    EQU     0
                FGX2_RELOC_COUNT 11
