*==============================================================================
*  prodos.link.s - Merlin32 link file for prodos.mod, the ProDOS filesystem
*  type.
*
*  Structurally identical to ufs.link.s.  The ORG's bank byte is the ordinal
*  $05: prodos packs into the shared module bank, after pty.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    prodos                    ; output filename
            ORG    $050000

            ASM    prodos.s
            SNA    ProdosModule
