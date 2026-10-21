*==============================================================================
*  isofs.link.s - Merlin32 link file for isofs.mod, the ISO 9660 filesystem
*  type.
*
*  Structurally identical to prodos.link.s.  The ORG's bank byte is the
*  ordinal $05: the module's own bank comes from modplace.s.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    isofs                     ; output filename
            ORG    $050000

            ASM    isofs.s
            SNA    IsofsModule
