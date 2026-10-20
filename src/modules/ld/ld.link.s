*==============================================================================
*  ld.link.s - Merlin32 link file for ld.mod, the shared-library registry
*  (see ld.s).  The same shape as every other module's.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    ld                         ; output filename
            ORG    $050000

            ASM    ld.s
            SNA    LdModule
