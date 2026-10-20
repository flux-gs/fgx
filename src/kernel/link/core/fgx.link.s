*==============================================================================
*  fgx.link.s - FGX kernel link file
*
*  Two-segment fixed-address build.  Merlin32 resolves ASM paths, and writes
*  'fgx' and its listings, relative to this file's directory, which no other
*  link shares; build.ninja moves the image to bin/fgx.bin and the listings to
*  build/.
*
*  Segment #1 : src/kernel/main.s (pulls in drivers, shell, console via PUT)
*  Segment #2 : src/drivers/block/block.s (ENT-exports Blk_Init, Blk_Read)
*==============================================================================

            TYP    $06                       ; Binary / fixed-address
            DSK    fgx                       ; Output name (ProDOS: 15 char max)
            ORG    $021000                   ; FGX_CODE: the page above the task
                                              ; table (16 TCBs x 64 B from $0800).
                                              ; Lockstep with include/kernel.s
                                              ; FGX_CODE and stage2 KERNEL_DEST.

*--- Segment #1: kernel main + drivers + shell + console
            ASM    ../../main.s
            SNA    KernelMain

*--- Segment #2: SmartPort block driver
            ASM    ../../../drivers/block/block.s
            SNA    BlockDriver
