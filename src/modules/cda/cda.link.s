*==============================================================================
*  cda.link.s - Merlin32 link file for the cda.mod module.
*  Output: a flat binary containing the FGXM header + text (the Desk Manager
*  SaveAll/RestAll patches that bracket the ROM's classic desk accessory menu).
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    cda                        ; output filename
            ORG    $050000

            ASM    cda.s
            SNA    CdaModule
