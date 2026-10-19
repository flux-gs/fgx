                FGX2_MODE 2
;---------------------------------------
; fcc 0.0 — generated from static_local_longname.c
;---------------------------------------

                MX      %00
                FGX2_EXPORT print_prompt_function_longname
print_prompt_function_longname            ENT
                PEI     _fcc_fb
                TSC
                SEC
                SBC     #print_prompt_function_longname_FRAMESIZE
                DO      print_prompt_function_longname_STKGUARD
                BCC     print_prompt_function_longname_stkovf
                CMP     _fcc_stkfloor
                BCS     print_prompt_function_longname_stkok
print_prompt_function_longname_stkovf       JMP     _fcc_stkoflow
                FIN
print_prompt_function_longname_stkok        TCS
                STA     _fcc_fb
                INC     _fcc_fb
                LDA     print_prompt_functio_sl0
                TAY
                TSC
                CLC
                ADC     #print_prompt_function_longname_FRAMESIZE
                TCS
                PLA
                STA     _fcc_fb
                TYA
                RTL
print_prompt_function_longname_FRAMESIZE   EQU     0
print_prompt_function_longname_STKGUARD    EQU     0
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
                FGX2_FARCALL print_prompt_function_longname
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
