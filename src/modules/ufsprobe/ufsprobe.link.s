*==============================================================================
*  ufsprobe.link.s - Merlin32 link file for ufsprobe.mod, the filesystem's
*  self-tests as a loadable module of their own.
*
*  Structurally identical to ufs.link.s.  ORG is an assembly-time convention
*  that PHK/PLB makes irrelevant at runtime; gen_modplace.py puts the real one
*  in modplace.s, and for this module the ORG's BANK BYTE is the ordinal $08,
*  because ufsprobe is the only member of module bank 3.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    ufsprobe                  ; output filename
            ORG    $080000

            ASM    ufsprobe.s
            SNA    UfsProbeModule
