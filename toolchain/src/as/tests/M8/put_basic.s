; M8: PUT — include a sibling file containing helper code.
                MX      %00
                LDA     #$42
                JSR     helper
                RTS
                PUT     put_helper
                ASC     'end'
