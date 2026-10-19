*==============================================================================
*  fgxfar.link.s - FGX far kernel bank link file
*
*  A SECOND link unit, not a third segment of fgx.link.s.  Merlin32 concatenates
*  a link file's segments into ONE image at ONE ORG, so a third segment would
*  share the core kernel bank's 57,968-byte ceiling and buy nothing.  A separate
*  link gets its own ceiling and its own listing.
*
*  Output 'fgxfar' and its listing beside this file, in a directory no other
*  link shares; build.ninja moves them to bin/fgxfar.bin and build/.  Staged
*  onto the disk image as /KERNELF.
*
*  ORG is FGX_KFAR_CODE ($080000), an ASSEMBLY-TIME convention only -- the same
*  way modules ORG at $050000.  At runtime the image lives in the kernel handle's
*  headroom bank (live kernel bank + 1) and far.s does PHK/PLB to suit.
*
*  Segment #1 : src/kernel/far/far.s
*==============================================================================

            TYP    $06                       ; Binary / fixed-address
            DSK    fgxfar                    ; Output name (ProDOS: 15 char max)
            ORG    $080000                   ; FGX_KFAR_CODE

*--- Segment #1: far-bank root (export table, Far_BankInit, migrated subsystems)
            ASM    ../../far/far.s
            SNA    FarMain
