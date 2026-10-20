*==============================================================================
*  dmesg.link.s - Merlin32 link file for the dmesg user binary.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    dmesg
            ORG    $0B0000

            ASM    dmesg.s
            SNA    DmesgMain
