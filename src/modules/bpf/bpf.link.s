*==============================================================================
*  bpf.link.s - Merlin32 link file for the bpf.mod module.
*  Output: a flat binary containing the FGXM header + text (ops + W5100 MACRAW
*  capture driver).  Registers /dev/bpf0 on load (mod_init).
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    bpf                        ; output filename
            ORG    $050000

            ASM    bpf.s
            SNA    BpfModule
