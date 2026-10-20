*==============================================================================
*  serial.link.s - Merlin32 link file for the serial.mod module.
*  Output: a flat binary containing the FGXM header + text.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    serial                    ; output filename
            ORG    $050000

            ASM    serial.s
            SNA    SerialModule
