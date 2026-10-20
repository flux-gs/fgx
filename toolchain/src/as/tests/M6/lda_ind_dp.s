; M6: LDA (dp) — 65816 plain DP-indirect (no index).
                MX      %00
                LDA     ($10)
                STA     ($20)
                ADC     ($30)
                CMP     ($40)
                RTS
