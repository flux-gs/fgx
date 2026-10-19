; M4: JSR — same-bank 3-byte absolute call.
                MX      %00
                JSR     sub
                RTS
sub             LDA     #$42
                RTS
