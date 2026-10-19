*==============================================================================
*  stat.link.s - Merlin32 link file for /bin/stat.
*  Output: a flat binary that build.sh stages at disk_src/BIN/STAT.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    stat                      ; output filename (no extension)
            ORG    $0B0000

            ASM    stat.s
            SNA    StatMain
