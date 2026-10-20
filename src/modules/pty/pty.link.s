*==============================================================================
*  pty.link.s - Merlin32 link file for the pseudo-terminal module.
*  Output: a flat binary containing the FGXM header + text.
*  The ORG here is DEAD: pty.s sets its own from MODP_ORG (generated), and
*  the inner ORG is what governs.  See tools/gen_modplace.py.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    pty                       ; output filename (no extension)
            ORG    $050000

            ASM    pty.s
            SNA    PtyModule
