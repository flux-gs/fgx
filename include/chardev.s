;==============================================================================
; chardev.s - character-device switch.
;
; FGX has no cdevsw: a character device node on the root (IFCHR) carries a
; chardev registry index as its rdev, and its specfs vnode (spec_vnops.c)
; dispatches through the registered CharDev_Ops vtable (src/kernel/chardev.s).
; docs/filesystem.md, "Device files", has the node lists and how they are
; generated.
;
; A module registers itself via MOD_REGISTERCHARDEV (include/modules.s), at the
; fixed index include/devnodes.s gives it.  The table holds up to CHARDEV_MAX
; entries;
; each entry caches the registered name + a long pointer to the
; module's CharDev_Ops + an opaque "minor" value the module gets back
; on every dispatch (useful when one module exports multiple devices,
; e.g. serial.mod with /dev/tty00 + /dev/tty01).
;
; This file emits zero binary bytes — pure EQU + DUM declarations.
;==============================================================================

; apple/fgx#330 took this from 16 to 24: the eight raw disk nodes
; (/dev/rsd0..rsd7) join eleven already registered, and sixteen slots could not
; hold them.  The table is a Kmalloc'd soft-global, so the cost is heap rather
; than kernel bank.  _Chardev_RegisterInternal's slot test carries the number a
; SECOND time as a literal; both move together.
CHARDEV_MAX     EQU     24              ; max registered char devices

; CDIDX_NDELAY -- WHERE THE IOFLAG RIDES INSIDE THE INDEX BYTE.
;
; The bulk seam has no register left for `flag': A is the uio offset, Y's high
; byte is the uio bank and its low byte the index, X the service number.  So
; IO_NDELAY travels as a bit of the index byte, and this is that bit -- which
; is NOT VFS_IO_NDELAY's own value.  It used to be: the flag rode in bit 4
; because VFS_IO_NDELAY is 16 and CHARDEV_MAX was 16, so an index could never
; reach it.  Eight raw disk nodes took CHARDEV_MAX past that, and index 16
; would have arrived indistinguishable from index 0 with NDELAY set.
;
; BIT 7, so the index has the whole rest of the byte.  The decode shifts it
; back down to VFS_IO_NDELAY rather than testing and loading, and the ERR in
; chardev.s pins the shift to the two constants so the arithmetic cannot drift
; away from them.
CDIDX_NDELAY    EQU     $80

; CDIDX_MASK -- the index byte with the flag bit taken off.
;
; The per-byte arms (jumptable.s's @kc_cdread and @kc_cdwrite) strip the flag
; before they use the index, and they did it with `AND #CHARDEV_MAX-1'.  That
; only ever worked because CHARDEV_MAX was a POWER OF TWO, which nothing said
; and nothing checked: at 24 the expression is $17, not a mask at all, and it
; rewrites index 9 as 1 and index 10 as 2 -- tty01 and bpf0 dispatching to
; ttyp0 and ttyp1.  Masking the flag's bit alone has no such dependency, and
; the bounds test each arm already runs is what refuses an index too large.
; kc_chardev.s's own header makes the wider point: an out-of-range index is
; REFUSED, never masked into a valid one.
CDIDX_MASK      EQU     $7F
; The longest name KSVC_CDLOOKUP will copy out of a caller's bank before giving
; up.  It is CD_Name's capacity, so a longer name cannot match anything that is
; registered and there is nothing to gain by copying it.
CDKCNAME_MAX    EQU     15

;------------------------------------------------------------------------------
; chardev_table[] entry layout.  Stored in bank-$02 statics
; (_chardev_table in memmap.s).  Record stride is rounded up from
; CD_SIZE to CD_REC_STRIDE so indexing is *24 (a single ASL/ADC chain)
; instead of *22 (which would need *24 - *2 or similar).
;------------------------------------------------------------------------------
                DUM     0
CD_NameLen      DS      1               ; 0..15
CD_Name         DS      15              ; not necessarily NUL-terminated
CD_OpsLo        DS      2               ; lo16 of long pointer to CharDev_Ops
CD_OpsBank      DS      1               ; bank byte (= module bank)
CD_Minor        DS      1               ; opaque, returned to module on every op
; apple/fgx#76: how many opens of THIS DEVICE are live.  BSD's closei() answers
; the same question by scanning the whole file table for another inode on the
; same i_rdev, and calls the driver's d_close only when it finds none -- so
; d_close means "the last close of this DEVICE", not of one file handle.
;
; FGX cannot do that scan cheaply: FCBs are per-fd heap allocations reached
; through PER-TASK fd tables, so the equivalent walk is tasks x fds rather than
; BSD's single array.  A count on the device itself computes the same predicate
; in O(1), and it is what two drivers had already started reconstructing by
; hand (pty's PTYF_MOPEN/SOPEN, and the open count #72's first cut wanted in
; TTY_Flags).  One central copy retires both.
CD_OpenCount    DS      1               ; live open(2)s of this device
; WHICH TTY IS THIS DEVICE, as a byte offset into _ttyTable; 0 = not a tty.
;
; This is the FGX half of what 2.11BSD gets from its line-discipline switch.
; Every BSD tty driver's write is two lines -- find my `struct tty *`, then
; `return ((*linesw[tp->t_line].l_write)(tp, uio, flag))` -- and ALL THREE
; disciplines point l_write at the same ttwrite().  So BSD has ONE write
; routine for every tty, and ttwrite's background-output gate is universal not
; because BSD checks in three places but because there is only one place.
;
; FGX has no such routine yet (apple/fgx#108 is the campaign to build it).  In
; the meantime this field supplies the operand -- the driver's `tp` -- so the
; line discipline's gate can serve every tty chardev, which is the same split
; BSD makes.
CD_TtyOff       DS      2               ; _ttyTable byte offset PLUS ONE; 0 = not
                                        ;   a tty.  The +1 is so tty[0], whose
                                        ;   offset IS 0, is distinguishable from
                                        ;   an unset field (apple/fgx#129).
; RECORD MODE IS A PROPERTY OF THE DEVICE, NOT OF A DESCRIPTOR, and that is
; BSD's shape rather than a convenience.  Reno's pty master keeps its state in
; pt_ioctl[minor(dev)], keyed by the DEVICE; ptcopen takes a `flag' argument and
; ignores it entirely (kern/tty_pty.c:228-248), and 2.11BSD agrees
; (tty_pty.c:201).  There is no per-descriptor record bit upstream because
; record mode is expressed by d_read consuming the uio as it sees fit.
;
; FGX had one anyway: _PtyM_Open and bpf's open set FCB_FL_RECORD through
; [_fcbPtr] -- an FCB their signature never mentions, and the WRONG one on the
; /dev route, where the namei walk lies between _Fcb_Alloc and the driver's
; open.  That is apple/fgx#198's other half.  Answering the question here
; retires both writes: the registry is keyed by device, exactly as
; pt_ioctl[minor(dev)] is.
;
; SET AT REGISTRATION, from Y's HIGH byte, which _Chardev_RegisterInternal
; previously discarded -- so every existing caller passes 0 and means it.
CD_Flags        DS      1               ; CDF_* bits
CD_SIZE         EQU     *               ; 24 bytes (deliberately) — see stride
                DEND
                ERR     CD_SIZE-1/$18   ; cap 24 B

CD_REC_STRIDE   EQU     24              ; record stride = CD_SIZE; both must agree

; CD_Flags bits.  A MODULE PASSES THEM IN Y's HIGH BYTE to MOD_REGISTERCHARDEV,
; and CDF_FIXED carries the device's NUMBER in bits 2-7 of that byte: the
; registry then fills THAT slot rather than the next free one, so the number
; a /dev node was made with (tools/ninja/gen.py DEV_NODES, generated into
; include/devnodes.s) does not depend on which modules registered before it
; on a given machine.  Only the low two bits are stored as CD_Flags.
CDF_RECORD      EQU     $01             ; one whole record per read(2): _Sys_Read
CDF_FIXED       EQU     $02             ; bits 2-7 = the chardev index to take
                                        ;   dispatches the read op ONCE and the
                                        ;   op fills the caller's buffer, rather
                                        ;   than looping a byte at a time

;------------------------------------------------------------------------------
; struct uio field offsets, for the ops that read one.
;
; THE AUTHORITY IS toolchain/tests/M37/vfslayout.c, which asserts these on the
; MACHINE against the real struct -- rc 81 for uio_resid, rc 83 for uio_rw.
; These EQUs are the assembly side of that pin and not a second authority: a
; field that moves fails the fixture, which fails the gate, before anything
; here can read the wrong one.  The numbers were read off fcc's own output for
; uiomove (LDY #10 for the uio_resid test, LDY #14 for uio_rw), not counted up
; from the declaration.
;
; HERE rather than in include/pty.s, where they started when pty.mod was the
; only assembly reader of a uio in the tree.  This header defines the bulk op
; ABI, so the layout its ops read belongs beside it, and pty.mod PUTs this file
; anyway -- one authority instead of a driver's header lending a constant to
; the ABI that governs it.
UIO_OFFSET      EQU     6               ; off_t: where in the device/file.  The
                                ;   raw disk reads it (rawdisk.s); the fixture
                                ;   pins it at 6 with rc 80.
UIO_RESID       EQU     10              ; unsigned short: bytes still to move
UIO_RW          EQU     14              ; int: UIO_READ 0 / UIO_WRITE 1
; The VALUES, for the paths that BUILD one -- the write side at T3 stage 3 and
; the read side at stage 4.  uio.h is the authority; these are its assembly
; side, like the offsets above.
;
; UIO_READ IS SPELLED OUT RATHER THAN LEFT AS "the other one".  It is 0, so
; `STZ' would set it and the constant would look like ceremony -- but a reader
; checking which direction a builder declares should find the same name on both
; arms.  The write builder's line is `LDA #UIO_WRITE'; the read builder's is
; `LDA #UIO_READ', and neither is a zero the next reader has to interpret.
UIO_READ        EQU     0               ; uio.h
UIO_WRITE       EQU     1               ; uio.h
UIO_USERSPACE   EQU     0               ; uio.h -- the caller's own buffer

; The table (CHARDEV_MAX entries) is a Kmalloc'd soft-global reached via the DP
; long-pointer _cdTablePtr (dpmap.s); allocated by _Chardev_InitBuiltins.  Was a
; 384-byte static _chardev_table in memmap.s -- moved to the heap so its address
; no longer drifts with kernel layout.
CDTAB_BLK_SIZE  EQU     CHARDEV_MAX*CD_REC_STRIDE   ; 576

;------------------------------------------------------------------------------
; CharDev_Ops vtable — what a chardev module exports.  Long-pointer
; table emitted by the module via:
;
;     module_ops      DFB <serial_open,>serial_open,^serial_open
;                     DFB <serial_close,>serial_close,^serial_close
;                     ...
;
; Each slot is a 3-byte long pointer.  Op entry conventions:
;   - MX %00 on entry.  Op may switch internally but must restore
;     MX %00 before RTL.
;   - DBR = the KERNEL's bank on entry, not the module's: _Chardev_Dispatch
;     does not change it.  An op that reads its own statics does PHB / PHK /
;     PLB itself; one that reads the kernel's (_Sys_Ioctl*, _Sys_Rd*) reads
;     them DBR-relative before it does.
;   - Carry: C=1 ok, C=0 + A = errno (see include/errno.s).
;   - Caller-saved scratch convention is the same as FOP_* — _fsTmp0/1/2
;     belong to the caller; ops must save anything else they need
;     across nested JSLs.
;
; Slot order is locked: tail-only additions.
;------------------------------------------------------------------------------
; THE FRAMES BELOW WERE NEVER BUILT, AND THIS TABLE SAID THEY WERE until UFS
; 1.13b read the drivers.  The design they describe -- an fcb pointer, a
; buffer and a length per call -- was replaced before the first driver shipped
; by a PER-BYTE dispatch, and the comment was not.  What actually arrives is
; what _Chardev_Dispatch loads (chardev.s:376-387):
;
;   Y = the device's MINOR byte, zero-extended
;   A = _cdArgByte, zero-extended -- the byte to send, for COPS_Write only
;   X = _cdArgFlag -- the `flag' argument, VFS_IO_NDELAY today
;
; and nothing on the stack at all.
;
; X WAS THE SECOND FICTION IN THIS FILE.  The two lines below had promised
; `X = flag' on COPS_Open and COPS_Close since the slots were declared, and it
; was never delivered: _Chardev_Dispatch left the COPS_* offset there.  It went
; unnoticed because no op read it -- which also means the register was free,
; so T2.2b made the promise true for EVERY op rather than deleting it.
;
; WHERE THE FLAG COMES FROM, per route, and neither is [_fcbPtr]:
;   syscall.s   translates the descriptor's FCB_CDF_NONBLK, which the FIONBIO
;               ioctl sets and _Sys_Ioctl resolves from its own fd.
;   the /dev route (jumptable.s's @kc_cdread / @kc_cdwrite) passes 0, and that
;               is CORRECT rather than a stub: vfs_vnops.c:374 records that
;               FNDELAY has no setter, so IO_NDELAY is unreachable through a
;               vnode.  When it has one, ioflag threads down to those arms.
; A driver reading non-blocking off [_fcbPtr] instead is apple/fgx#198's other
; half -- an FCB its signature never mentions, and the WRONG one on the /dev
; route, where the namei walk lies between _Fcb_Alloc and the driver.  Getc returns ONE byte in A with C=1, or
; C=0 with A=0 for end of file and A=errno otherwise; putc takes one byte and
; answers C=1 or C=0+errno.  spec_chread/spec_chwrite loop over them a byte at
; a time.  THE BULK SLOTS BELOW ARE THE OTHER HALF and take an ordinary stack
; frame -- they are the only ops that do, which is why this note is about the
; per-byte pair specifically.
;
; SOME OPS READ MORE THAN THEIR ARGUMENTS.  _Ttyv_Write reads _Sys_WrCdIdx to
; learn which line it is writing to (ttyv.s:159), so a caller that dispatches
; without setting it gets the previous caller's line.  That is a property of
; the seam and not of ttyv: any new caller must set it, which is why
; jumptable.s's @kc_cdwrite does.
;------------------------------------------------------------------------------
; TWO ENTRIES PER DIRECTION, AND THAT IS BSD'S OWN SPLIT, not two ABIs.
;
; apple/fgx#108 T2.2.  cdevsw's `d_read(dev, uio, flag)' is the entry a caller
; that HAS a uio uses -- spec_vnops' VCHR arm, and read(2) once the syscall
; layer builds one.  It moves as much as it can and answers an errno.  The
; per-byte pair below it is FGX's primitive, the one a caller WITHOUT a uio
; uses: the discipline's echo and output reach a line through
; `_FarSh_CdWrite' one byte at a time, with no uio.
;
; A DRIVER EITHER FILLS THE BULK SLOT OR LEAVES IT ZERO, and which it does IS
; its declaration of what it is:
;
;   PER-BYTE devices leave d_read ZERO.  The caller -- which has a uio and
;   therefore already has a loop -- keeps using it over cd_getc.  No new code
;   in the driver, and no entry to get wrong.
;
;   RECORD-MODE devices (pty master, bpf) point d_read at their own routine,
;   which fills the uio whole.  THIS IS THE HALF apple/fgx#198 SAYS THEY CANNOT
;   EXPRESS TODAY: their read fills a buffer and returns a COUNT, spec_chread
;   reads that count as one byte's value, and the buffer is silently refilled
;   from the top on the next call.  With a bulk slot they say so in the table
;   instead of writing a record-mode bit onto an FCB their signature never
;   mentions.
;
; So the pair is not a transition state to be collapsed later.  BSD has the
; same two levels -- d_read for the caller, and the discipline's own primitives
; underneath -- and FGX's cd_getc/cd_putc are that lower level.
;
;------------------------------------------------------------------------------
; A ZERO BULK SLOT MEANS "I AM PER-BYTE", and that is why it is zero rather
; than a pointer to a shared generic routine.
;
; _Chardev_Dispatch JSLs through the DEVICE'S OWN BANK (CD_OpsBank), so a
; vtable in serial.mod cannot name a routine in the core kernel -- the address
; would be read in the wrong bank.  Every driver naming its own copy of the
; same generic loop is the alternative, and it is worse.  So the absence of a
; routine is the declaration, and the CALLER -- which is the one that has a uio
; and therefore already has a loop -- keeps using it.
;
; THE POINTER TRAVELS ON THE STACK AND MUST.  A bulk op can BLOCK: _PtyM_Write
; sleeps when the pty ring fills.  apple/fgx#89 is what happens when state a
; blocking chardev op depends on lives in a kernel singleton -- the old
; per-byte write loop's counters were statics, another task's write overwrote them during
; the sleep, and the blocked writer resumed with a foreign count and walked
; into adjacent statics.  Staging a uio pointer in a static to get it past a
; register-based KSVC would be that defect again, so the bulk ops take an
; ordinary frame and the shim that reaches them forwards it.
;------------------------------------------------------------------------------
                DUM     0
COPS_Open       DS      3               ; d_open:  Y = minor, X = flag      -> C=1 / C=0+errno
COPS_Close      DS      3               ; d_close: Y = minor, X = flag      -> C=1 / C=0+errno
COPS_Getc       DS      3               ; FGX primitive.  Y = minor, X = flag
                                        ;   -> A.lo = one byte, C=1;
                                        ;   C=0 + A=0 is EOF, A=errno is an error
COPS_Putc       DS      3               ; FGX primitive.  Y = minor, X = flag,
                                        ;   A.lo = the byte  -> C=1 / C=0+errno
COPS_Ioctl      DS      3               ; d_ioctl: Y = minor, X = flag      -> C=1 / C=0+errno
COPS_Poll       DS      3               ; d_select: Y = minor, X = flag -> A = POLL* mask
COPS_DRead      DS      3               ; d_read(dev, uio, flag).  ZERO = this
                                        ;   device has none; see the note above.
                                        ;   -> A = errno (0 = ok)
COPS_DWrite     DS      3               ; d_write(dev, uio, flag)  -> A = errno
COPS_Stop       DS      3               ; d_stop(dev, rw).  Y = minor, X = rw.
                                        ;   HALT OUTPUT ALREADY IN FLIGHT.  The
                                        ;   caller has already set TS_TTSTOP, so
                                        ;   this is not the software stop -- it
                                        ;   is the hardware half, and ZERO is a
                                        ;   correct value for any device with
                                        ;   nothing in flight.  2.11BSD's own
                                        ;   cdevsw gives the CONSOLE `nulldev'
                                        ;   here (pdp/conf.c, cn = 0); only the
                                        ;   dz/dh/dhu multiplexers have a body.
                                        ;   APPENDED rather than placed at
                                        ;   BSD's position (after d_ioctl)
                                        ;   because inserting would renumber
                                        ;   every slot below it and force every
                                        ;   vtable in the tree to be reordered;
                                        ;   FGX's slot ORDER already differs
                                        ;   (Getc/Putc are not d_read/d_write),
                                        ;   so appending costs no fidelity.
COPS_SIZE       EQU     *               ; 27 bytes
                DEND

; THERE IS NO d_strategy SLOT, AND THAT IS A DECISION.  Reno's `struct cdevsw'
; carries one (sys/conf.h:47) so a character row can name the block driver's
; strategy -- but it is read in exactly two places in the whole kernel,
; `rawread' and `rawwrite' (kern/vm_swp.c:334,342), and exactly one hp300 row
; uses those: the swap device, which has no driver of its own to write a
; wrapper in.  Every disk names its strategy directly in C
; (`physio(sdstrategy, ...)', sd.c:677).  FGX has ONE block driver, reached by
; device index, so rawdisk.s names Blk_Read/Blk_Write outright and a lookup
; slot would be locked ABI with nothing to disambiguate.  If a second raw
; device ever wants a shared generic routine, that is when the slot earns its
; place.

; Poll event bits returned in A from COPS_Poll.
POLLIN          EQU     $0001           ; data available to read
POLLOUT         EQU     $0004           ; write would not block

;==============================================================================
; END chardev.s
;==============================================================================
