; M6: LDA (dp,X) — pre-indexed-X indirect.  Less common but
; expressible; round out the indirect-mode coverage.
                MX      %00
                LDA     ($10,X)
                STA     ($20,X)
                CMP     ($30,X)
                RTS
