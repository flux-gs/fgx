*==============================================================================
*  klog.link.s - Merlin32 link file for the klog.mod module.
*  Output: a flat binary containing the FGXM header + text.  Registers
*  /dev/klog on load (mod_init), a cursored read-only view of the kernel log
*  ring for syslogd.
*==============================================================================

            TYP    $06                       ; ProDOS BIN
            DSK    klog                       ; output filename
            ORG    $050000

            ASM    klog.s
            SNA    KlogModule
