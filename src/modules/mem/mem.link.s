*==============================================================================
*  mem.link.s - Merlin32 link file for the mem.mod module.
*  Output: a flat binary containing the FGXM header + text.  Registers
*  /dev/mem and /dev/kmem on load (mod_init), 2.11BSD mmrw's minors 0 and 1.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    mem                       ; output filename
            ORG    $050000

            ASM    mem.s
            SNA    MemModule
