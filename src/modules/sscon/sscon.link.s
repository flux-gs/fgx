*==============================================================================
*  sscon.link.s - Merlin32 link file for the Second Sight console module.
*  Output: a flat binary containing the FGXM header + text.
*  The ORG here is DEAD: sscon.s sets its own from MODP_ORG (generated), and
*  the inner ORG is what governs.  See tools/gen_modplace.py.
*==============================================================================
            TYP    $06                       ; ProDOS BIN
            DSK    sscon                     ; output filename (no extension)
            ORG    $050000
            ASM    sscon.s
            SNA    SsconModule
