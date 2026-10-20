*==============================================================================
*  font.link.s - Merlin32 link file for /bin/font.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    font                      ; output filename (no extension)
            ORG    $0B0000

            ASM    font.s
            SNA    FontMain
