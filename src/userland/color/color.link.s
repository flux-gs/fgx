*==============================================================================
*  color.link.s - Merlin32 link file for /bin/color.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    color                     ; output filename (no extension)
            ORG    $0B0000

            ASM    color.s
            SNA    ColorMain
