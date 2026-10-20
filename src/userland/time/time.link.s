*==============================================================================
*  time.link.s - Merlin32 link file for /bin/time.
*  Output: a flat binary that build.sh stages at disk_src/BIN/TIME.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    time                      ; output filename (no extension)
            ORG    $0B0000

            ASM    time.s
            SNA    TimeMain
