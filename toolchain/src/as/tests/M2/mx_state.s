; M2: MX state alternation affects immediate sizing.
                MX      %00
                LDA     #$ABCD
                MX      %11
                LDA     #$EE
                MX      %00
                LDA     #$1234
