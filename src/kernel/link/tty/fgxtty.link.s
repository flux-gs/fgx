*==============================================================================
*  fgxtty.link.s - FGX tty kernel bank link file
*
*  A THIRD link unit, sibling of fgxfar.link.s and for the same reason: Merlin32
*  concatenates a link file's segments into ONE image at ONE ORG, so a further
*  segment of an existing link would share that link's 57,968-byte ceiling and
*  buy nothing.  A separate link gets its own ceiling and its own listing.
*
*  Output 'fgxtty' and its listing beside this file, in a directory no other
*  link shares; build.ninja moves them to bin/fgxtty.bin and build/.  Staged
*  onto the disk image as /KERNELTTY.
*
*  ORG is FGX_KTTY_CODE ($090000), an ASSEMBLY-TIME convention only -- the same
*  way the far bank ORGs at $08 and modules at $05.  At runtime the image lives
*  in the kernel handle's second headroom bank (live kernel bank + 2) and
*  ttybank.s does PHK/PLB to suit.
*
*  Segment #1 : src/kernel/tty/ttybank.s
*==============================================================================

            TYP    $06                       ; Binary / fixed-address
            DSK    fgxtty                    ; Output name (ProDOS: 15 char max)
            ORG    $090000                   ; FGX_KTTY_CODE

*--- Segment #1: tty-bank root (export table, Tty_BankInit, the tty layer)
            ASM    ../../tty/ttybank.s
            SNA    TtyMain
