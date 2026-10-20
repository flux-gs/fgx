*==============================================================================
*  ls.link.s - Merlin32 link file for /bin/ls.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    ls                        ; output filename (no extension)
            ORG    $0B0000

            ASM    ls.s
            SNA    LsMain
