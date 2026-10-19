*==============================================================================
*  date.link.s - Merlin32 link file for /bin/date.
*  Output: a flat binary that build.sh stages at disk_src/BIN/DATE.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    date                      ; output filename (no extension)
            ORG    $0B0000

            ASM    date.s
            SNA    DateMain
