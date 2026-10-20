*==============================================================================
*  ramdisk.link.s - Merlin32 link file for the /RAM5 RAM-disk module.
*  Output: a flat binary containing the FGXM header + text.
*  The ORG here is DEAD: ramdisk.s sets its own from MODP_ORG (generated), and
*  the inner ORG is what governs.  See tools/gen_modplace.py.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    ramdisk                   ; output filename (no extension)
            ORG    $050000

            ASM    ramdisk.s
            SNA    RamDiskModule
