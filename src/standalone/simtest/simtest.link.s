*==============================================================================
*  simtest.link.s - Merlin32 link file for the SIM-validation standalone.
*  Output: a flat binary that boots at $022000 (same as /FGX/KERNEL).
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    simtest                   ; output filename
            ORG    $022000

            ASM    simtest.s
            SNA    SimtestStandalone
