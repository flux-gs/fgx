*==============================================================================
*  vfs.link.s - Merlin32 link file for vfs.mod, the BSD VFS as a loadable
*  module.
*
*  Structurally identical to every other module's link file, including
*  hellokc's -- TYP/DSK/ORG/ASM/SNA.  ORG is an assembly-time convention that
*  PHK/PLB makes irrelevant at runtime; gen_modplace.py puts the real one in
*  modplace.s, and for this module the ORG's BANK BYTE is the ordinal $06,
*  because vfs is the only member of module bank 1.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    vfs                       ; output filename
            ORG    $060000

            ASM    vfs.s
            SNA    VfsModule
