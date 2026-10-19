*==============================================================================
*  fpsim.link.s - Merlin32 link file for fpsim.mod, the floating point
*  simulator module (see fpsim.s).  The same shape as every other module's.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    fpsim                      ; output filename
            ORG    $050000

            ASM    fpsim.s
            SNA    FpsimModule
