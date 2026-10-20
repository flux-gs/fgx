;---------------------------------------
; fcc 0.0 — generated from pp_main.c
;---------------------------------------

                MX      %00
main            ENT
                JSR     helper
                PHA
                LDA     #0
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                PHA
                LDA     #42
                STA     _fcc_tmp_b
                PLA
                SEC
                SBC     _fcc_tmp_b
                PHA
                LDA     #42
                STA     _fcc_tmp_b
                PLA
                CLC
                ADC     _fcc_tmp_b
                RTS
