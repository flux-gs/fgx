*==============================================================================
*  ufsdir.link.s - Merlin32 link file for ufsdir.mod, the NAME half of UFS.
*
*  Structurally identical to ufs.link.s.  ORG is an assembly-time convention
*  that PHK/PLB makes irrelevant at runtime; gen_modplace.py puts the real one
*  in modplace.s, and for this module the ORG's BANK BYTE is the ordinal $09,
*  because ufsdir is the only member of module bank 4.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    ufsdir                    ; output filename
            ORG    $090000

            ASM    ufsdir.s
            SNA    UfsDirModule
