*==============================================================================
*  ufs.link.s - Merlin32 link file for ufs.mod, the 2.11BSD filesystem as a
*  loadable module.
*
*  Structurally identical to vfs.link.s.  ORG is an assembly-time convention
*  that PHK/PLB makes irrelevant at runtime; gen_modplace.py puts the real one
*  in modplace.s, and for this module the ORG's BANK BYTE is the ordinal $07,
*  because ufs is the only member of module bank 2.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    ufs                       ; output filename
            ORG    $070000

            ASM    ufs.s
            SNA    UfsModule
