                MX      %11
                ORG     $0B0000
                ASC     'FGX1'
                DFB     <$0B0000
                DFB     >$0B0000
                DFB     ^$0B0000
                DFB     $00
                DA      _entry-$0B0000
                DA      _end-_text
                DA      0
                DFB     $00
                DFB     $00
_text           EQU     *
_entry          MX      %00
                REP     #$30
                LDA     #0
                JSL     $000328
                DFB     1
                BRA     *
_end            EQU     *
