*==============================================================================
*  prodosw.link.s - Merlin32 link file for prodosw.mod, the write half of the
*  ProDOS filesystem type.
*
*  Structurally identical to prodos.link.s.  The ORG's bank byte is the
*  ordinal $0B: prodosw is the only member of module bank 6.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    prodosw                   ; output filename
            ORG    $0B0000

            ASM    prodosw.s
            SNA    ProdosWModule
