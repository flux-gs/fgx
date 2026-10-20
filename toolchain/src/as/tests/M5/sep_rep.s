; M5: SEP/REP — always 1-byte immediate (MX-insensitive).
; MX directive is paired with SEP/REP to keep the assembler's
; static MX-tracking in sync with runtime — fas mirrors Merlin
; here (SEP/REP do NOT auto-update fas's MX state).
                MX      %11
                REP     #$30
                MX      %00
                LDA     #$1234
                SEP     #$20
                MX      %10
                LDA     #$42
                RTS
