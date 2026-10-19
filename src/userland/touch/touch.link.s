*==============================================================================
*  touch.link.s - Merlin32 link file for /bin/touch.
*  Output: a flat binary that build.sh stages at disk_src/BIN/TOUCH.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    touch                     ; output filename (no extension)
            ORG    $0B0000

            ASM    touch.s
            SNA    TouchMain
