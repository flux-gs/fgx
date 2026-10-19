; M6: LDA [dp] and LDA [dp],Y — long-pointer deref forms.  These
; carry the 24-bit bank byte through the DP pointer, used by fcc
; long-pointer codegen.
                MX      %00
                LDA     [$10]
                STA     [$20]
                ADC     [$30]
                LDA     [$40],Y
                STA     [$50],Y
                ADC     [$60],Y
                RTS
