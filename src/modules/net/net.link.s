*==============================================================================
*  net.link.s - Merlin32 link file for net.mod (the networking stack module).
*  Output: a flat binary containing the FGXM header + text (the net_op_table +
*  the SYS_IFCONFIG / socket / transport ops lifted out of the kernel).
*  Registers a VT_NET vtable on load (mod_init); the kernel dispatches socket
*  syscalls into it via _Net_Dispatch (src/kernel/net_dispatch.s).
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    net                        ; output filename
            ORG    $050000

            ASM    net.s
            SNA    NetModule
