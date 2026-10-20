;==============================================================================
; kfar.s - Far kernel bank ABI.  Shared by fgx.link.s and fgxfar.link.s.
;
; The far bank is a SECOND statically linked kernel image.  Geometry constants
; (FGX_KFAR_BANK/CODE/DATA) live in kernel.s; this file is the calling contract.
; See docs/history/plans/far-kernel-bank.md.
;
;------------------------------------------------------------------------------
; THE EXPORT SLOTS ARE `JMP abs16`, NOT `JML`, AND ARE NEVER PATCHED.
;
; A core caller does `JSL <farbank>:<slot>`.  That JSL sets PBR = far bank BEFORE
; the slot executes, so a 16-bit JMP inside the slot already lands in the right
; bank.  Only the CALLER's JSL operand bank byte needs patching, core-side.
;
; This is why there is no chicken-and-egg about who patches the patcher: the
; table is correct the moment it is assembled, and the only runtime fixups are
; on the calling side.  A JML table would have needed its own bank bytes fixed
; up by code that would itself have had to be reached somehow.
;
; Slot stride is 4 (3-byte JMP + 1 pad) to match MOD_JT_GATEWAY's shape in
; include/modules.s, so the two tables read the same way.
;------------------------------------------------------------------------------

KFAR_MAGIC          EQU     $4B46           ; 'FK' -- validity marker
KFAR_ABI_VERSION    EQU     $0001

;------------------------------------------------------------------------------
; THE TABLE SITS AT OFFSET $0000, AND THAT IS FORCED BY THE LINKER.
;
; Merlin32 emits only real bytes: it does NOT pad the gap between two ORGs.  An
; earlier draft put this table at $FE00 and the init entry at $FD00, and the
; resulting binary was 150 bytes of packed code with the offsets thrown away --
; loading it at bank:0000 would have put the init entry at offset 0 rather than
; $FD00, and every slot address would have been wrong.  Anchoring the table at
; the base of the bank keeps the image contiguous, small, and correct.
;
; Subsystem code therefore grows UP from just above the table.
;------------------------------------------------------------------------------
KFAR_EXPORT_BASE    EQU     $0000           ; export table base (offset in bank)

KFAR_HDR_MAGIC      EQU     KFAR_EXPORT_BASE+$00    ; word: KFAR_MAGIC
KFAR_HDR_ABIVER     EQU     KFAR_EXPORT_BASE+$02    ; word: KFAR_ABI_VERSION
KFAR_HDR_RESERVED   EQU     KFAR_EXPORT_BASE+$04    ; word: reserved, 0

;------------------------------------------------------------------------------
; FAR-BANK STATICS THE CORE KERNEL MUST NAME live at FIXED offsets, declared
; here and asserted in far.s -- they are NOT scraped.
;
; Scraping would invert the build: the far bank is assembled FROM the core
; listing (kernel_exports.s), so having core depend on far addresses in turn
; makes the graph cyclic.  The export table avoids this by sitting at a fixed
; EQU offset; static regions the core reads do the same.
;
; CON_VT_STATE is the only one today: syscall.s touches it at 14 sites -- the
; deferred-flush timestamp and the hi-res profiling block -- by patched LDAL.
;------------------------------------------------------------------------------
KFAR_VT_STATE       EQU     $EC40           ; == FGX_KFAR_DATA offset; first entry
                                            ;   in the far bank's DUM, ERR-checked

; THE RESERVATION HAS TO EXCEED THE HIGHEST ASSIGNED SLOT, and for a long time
; it did not.  It was 32 with slots 0..38 assigned, which made
; `LUP KFAR_SLOT_COUNT-39' in far.s a LUP of -7: merlin32 emits nothing for that,
; so the bank carried NO unassigned-slot stubs and the contract below was false.
; A call to slot 39 landed on $00A2, which was `_KZeroRegion PHP' -- an MVN
; block-zero entered with whatever was in A and X, rather than a red border.
; Two further consequences: KFAR_TABLE_SZ understated the table by seven slots,
; so check_far_calls.py's "is this constant a slot address" window was short by
; that much; and the "never a layout change" promise on the next line stopped
; holding at slot 32, every slot since having shifted all far-bank code below it.
; apple/fgx#210.  The ERR at the foot of far.s's table is what now says so: the
; emitted table must be exactly KFAR_TABLE_SZ bytes, which a swallowed LUP is not.
; RAISED FROM 64 TO 96 ON 2026-09-06, and that raise is ITSELF the one layout
; change the reservation exists to prevent -- every far-bank byte above the
; table moved 128 bytes up, and `gen_far_bankpatch.py --check' is what said so
; and regenerated the sites.  It was done once, deliberately, with the bank at
; 11,242 bytes free, rather than a slot at a time under pressure: slot 63 was
; the last of the original 64 and mount(2)/umount(2) needed two.  32 spare
; slots cost 128 bytes and restore the property the comment below describes.
KFAR_SLOT_COUNT     EQU     96              ; reserved ahead, so adding
                                            ;   an export is never a layout change
KFAR_SLOT0          EQU     KFAR_EXPORT_BASE+$06
KFAR_TABLE_SZ       EQU     $06+4*KFAR_SLOT_COUNT   ; $186 -- code starts above this

;------------------------------------------------------------------------------
; Export slots.  Slot n = KFAR_SLOT0 + 4n.  Unassigned slots JMP to a red-border
; halt (_Far_StubHalt), the same loud-failure contract include/modules.s gives
; unwired MOD_JT slots -- an accidental call must not silently fall through.
;
; SLOT 0 IS THE INIT ENTRY.  It needs no special fixed offset of its own: slots
; are JMP abs16 and are never patched, so the table is already correct the moment
; it is assembled and there is no bootstrap ordering problem.
;
; Assigned by the task that adds the export.  Keep this list dense and in slot
; order; a gap is a wasted slot, not a bug, but it makes the table harder to read.
;------------------------------------------------------------------------------
KFAR_INIT           EQU     KFAR_SLOT0+4*0  ; slot 0: Far_BankInit
KFAR_SOUND_INIT     EQU     KFAR_SLOT0+4*1  ; slot 1: Sound_Init
KFAR_SOUND_STOPDOC  EQU     KFAR_SLOT0+4*2  ; slot 2: Sound_StopDoc
KFAR_SOUND_BEEP     EQU     KFAR_SLOT0+4*3  ; slot 3: Sound_Beep
KFAR_CAPTURE_BOOTTIME EQU KFAR_SLOT0+4*4  ; slot 4: _KCaptureBootTime
KFAR_SYS_UPTIME     EQU     KFAR_SLOT0+4*5  ; slot 5: _Sys_Uptime   (#51)
KFAR_SYS_RTCREAD    EQU     KFAR_SLOT0+4*6  ; slot 6: _Sys_RtcRead  (#31)
; slot 7: unassigned.  settimeofday(2) is the kernel clock's, in the tty bank.
KFAR_LOG_STATE      EQU     KFAR_SLOT0+4*8  ; slot 8: Far_LogState
KFAR_BOOT_CHIME     EQU     KFAR_SLOT0+4*9  ; slot 9: Far_BootChime

; --- console driver, slots 10-23 (17 files, 9,555 B) ---
KFAR_CON_INIT       EQU     KFAR_SLOT0+4*10 ; slot 10: Con_Init
KFAR_CON_WRITE      EQU     KFAR_SLOT0+4*11 ; slot 11: Con_Write
KFAR_CON_WRITEBUF   EQU     KFAR_SLOT0+4*12 ; slot 12: Con_WriteBuf
KFAR_CON_PUTCHAR    EQU     KFAR_SLOT0+4*13 ; slot 13: Con_PutChar
KFAR_CON_CR         EQU     KFAR_SLOT0+4*14 ; slot 14: Con_CR
KFAR_CON_POLLKEY    EQU     KFAR_SLOT0+4*15 ; slot 15: Con_PollKey
KFAR_CON_GETKEY     EQU     KFAR_SLOT0+4*16 ; slot 16: Con_GetKey
KFAR_CON_RENDERALL  EQU     KFAR_SLOT0+4*17 ; slot 17: Con_RenderAll
KFAR_CON_SHOWCURSOR EQU     KFAR_SLOT0+4*18 ; slot 18: Con_ShowCursor
KFAR_CON_HIDECURSOR EQU     KFAR_SLOT0+4*19 ; slot 19: Con_HideCursor
KFAR_CON_INITSCBS   EQU     KFAR_SLOT0+4*20 ; slot 20: _Con_InitSCBs
KFAR_CON_INSTALLPALETTES EQU     KFAR_SLOT0+4*21 ; slot 21: _Con_InstallPalettes
KFAR_CON_LOADFONTFROMFILE EQU     KFAR_SLOT0+4*22 ; slot 22: Con_LoadFontFromFile
KFAR_CON_REVERTTODEFAULT EQU     KFAR_SLOT0+4*23 ; slot 23: Con_RevertToDefault
KFAR_CON_SWITCHVC   EQU     KFAR_SLOT0+4*24 ; slot 24: Con_SwitchVC (slice D)
KFAR_CON_ENTERVC    EQU     KFAR_SLOT0+4*25 ; slot 25: Con_EnterVC  (slice D)
KFAR_CON_LEAVEVC    EQU     KFAR_SLOT0+4*26 ; slot 26: Con_LeaveVC  (slice D)

; --- kernel C, slot 27 ---
; The slot JMPs STRAIGHT AT the C function, with no _fw_ wrapper: fcc functions
; end in RTL and read arguments at n,S off a 3-byte return frame, which is
; exactly what the caller's JSL leaves.  A PHB/PHK/PLB shim would insert four
; bytes between the arguments and the callee, so DBR is switched on the CALLING
; side instead -- see KC_ENTER in include/kernelc.s.
KFAR_KC_PROBE       EQU     KFAR_SLOT0+4*27 ; slot 27: kc_probe (C)
; SLOT 28 IS THE INWARD SEAM AS OF UFS 1.7d, and that is a restoration rather
; than a reuse.  It was `bufinit' until 2026-08-12, when the VFS became vfs.mod
; and brought itself up at module load, leaving the core with nothing to call.
; The seam is the kernel-to-VFS call coming back -- to the same slot, because
; the table's shape is ABI and nothing else may move.
KFAR_VFS_SEAM       EQU     KFAR_SLOT0+4*28 ; slot 28: the inward seam (was
                                            ;   bufinit).  Resolves VT_VFSCORE
                                            ;   and proves one round trip.
; SLOTS 29 AND 30 ARE THE DESCRIPTOR SERVICE as of UFS 1.7d I2b, restored the
; same way slot 28 was: they were vfs_probe and vfs_init until the VFS became a
; module, and the core bank's FS layer is what calls them now.
KFAR_VFS_DESCALLOC  EQU     KFAR_SLOT0+4*29 ; slot 29: kdesc_alloc(pid, fcb,
                                            ;   fdp) -> errno (was vfs_probe)
KFAR_VFS_DESCFREE   EQU     KFAR_SLOT0+4*30 ; slot 30: kdesc_free(pid, fd)
                                            ;   -> errno (was vfs_init)
KFAR_VFS_FILEINIT   EQU     KFAR_SLOT0+4*31 ; slot 31: carve the file table,
                                            ;   before any module loads
; SLOTS 32 AND 33 ARE THE PROCESS LIFECYCLE'S HALF of the same service.  The
; kernel fd table is inherited at spawn/vfork (_Task_CopyParentFds) and
; released at teardown (Task_FreeFdTable); the file table has to make the same
; two moves at the same two places, or the two tables disagree about which
; descriptors a process holds -- which shows up as a child's first open(2)
; being handed fd 0 over its own inherited stdin.
KFAR_VFS_DESCCOPY   EQU     KFAR_SLOT0+4*32 ; slot 32: fdcopy(frompid, topid)
                                            ;   -> errno
KFAR_VFS_DESCFREEALL EQU    KFAR_SLOT0+4*33 ; slot 33: fdfreeall(pid) -> errno
; SLOTS 34 AND 35 COMPLETE THE MIRROR (UFS 1.7d I2c).  _Fd_Dup and
; _Sys_ApplyFdActions were the only two writers of the fd table that did not
; reach _Fcb_Alloc/_Fcb_Free, so they were the only two that could leave a
; descriptor live in one table and absent from the other.
KFAR_VFS_DESCDUP    EQU     KFAR_SLOT0+4*34 ; slot 34: fddup(pid, old, new)
KFAR_VFS_DESCMOVE   EQU     KFAR_SLOT0+4*35 ; slot 35: fdmove(pid, old, new)
; SLOT 36 MOUNTS /dev -- UFS 1.7d I3.  It is a kernel act rather than a
; module's: ufs.mod's mod_init runs before ufsdir.mod loads, and iget refuses
; to mint a vnode until ufsdir is up, so a mount there would find no root.
; After Mod_LoadConf is the first moment the filesystem is whole.
; SLOT 37 IS FREE.  It and slot 36 were the /dev VOLUME's open and mount, and
; both went with it on 2026-09-05: the root carries its own /dev, the mount
; declined on every boot this kernel makes, and _Sys_DevOpen had already lost
; its own caller.  src/kernel/far/dev_mount.c's header carries the measurement.
;
; slot 36: vfs_sync() -- sync(2)'s walk of the mount list.  NO ARGUMENTS and no
; return.  apple/fgx#332: nothing wrote the superblock back, so blocks handed
; out since the last free-list refill stayed on the on-disk free list and were
; given away again after a remount.
;
; THE NUMBER IS REUSED AND THE ONE BESIDE IT IS NOT, which is a judgement worth
; recording: a slot is only dangerous to reuse while something might still CALL
; the old occupant, and every caller of both went in the same commit that
; emptied them.  36 is taken because a sync walk is what the /dev mount's slot
; was always for -- filesystem housekeeping on the boot path -- and 37 is now
; the OTHER sync walk, the one a machine does on its way down.  The gap that
; was left open for a reader tracing an old listing has served that purpose and
; is spent on its nearest relative.
KFAR_VFS_SYNC       EQU     KFAR_SLOT0+4*36
KFAR_VFS_SYNCCLEAN  EQU     KFAR_SLOT0+4*37 ; slot 37: vfs_syncclean() -- the
                                            ;   sync a machine does on its way
                                            ;   down, leaving every writable
                                            ;   mount that was clean at mount
                                            ;   MARKED clean (apple/fgx#403).
                                            ;   37 was the gap the note above
                                            ;   describes; a shutdown sync
                                            ;   beside the ordinary one is what
                                            ;   it is now.
KFAR_VFS_DEVRW      EQU     KFAR_SLOT0+4*38 ; slot 38: dev_rw(pid, fd, uio)
                                            ;   -> count, or -errno
; KFAR_VFS_DEVIOCTLSEL - slot 43: dev_ioctlsel(pid, fd, com, data, isioctl).
; UFS 1.7d I4.  ONE slot for ioctl(2) and select(2) both, because what differs
; between them is a boolean and a second slot would have bought a second copy
; of the argument copy that is the whole cost of the crossing.
;   isioctl != 0 -> 0, or -errno
;   isioctl == 0 -> a two-bit readiness mask (1 readable, 2 writable), or -errno
; It is NOT slot 39: the loader took 39-42 when the core bank ran out, and the
; assignment is append-only ABI.
KFAR_VFS_DEVIOCTLSEL EQU    KFAR_SLOT0+4*43
; slot 44: root_mount() -> 0, -1 (not a 2.11BSD volume) or -2.  UFS 2.4b.
; Called ONCE, from main.s, right after the /dev mount -- which is also what
; guarantees vfs_mountinit has run, since dev_mount calls it.
KFAR_VFS_ROOTMOUNT  EQU     KFAR_SLOT0+4*44
; slot 45: root_open(pid, fd, name, fmode, cmode) -> 0 or errno.  UFS 2.4.
; dev_open's sibling one slot on: finish an open of an ABSOLUTE path against
; the mounted root, on a descriptor _Fcb_Alloc already made.  The core's hook
; falls through on any error, so ENXIO from here means "no root mounted, use
; the legacy resolver" rather than anything a user sees.
; TWELVE ARGUMENT BYTES since the create mode was carried; it was ten, and
; both sides of a slot must agree on the width because a short push is silent
; -- the callee builds its frame from whatever lies under the last argument.
; The pusher is _Fs_RootOpen (src/drivers/fs/fs.s).
KFAR_VFS_ROOTOPEN   EQU     KFAR_SLOT0+4*45

; slot 46: root_stat(name, sb) -> 0 or errno.  The path-syscall conversion.
; root_open's sibling, and the FIRST of the nine Path_Resolve entry points to
; be answered by namei instead: a plain LOOKUP, VOP_GETATTR, and a copy into
; the core's `_fsStatBuf'.  It fills the LEGACY 15-byte ST_ image on purpose --
; the BSD STX_ layout replaces it when ProDOS stops being a filesystem this
; kernel resolves through, and converting the ProDOS arm first would need a
; ProDOS-date-to-epoch conversion in 65816.  Same fall-through contract as
; slot 45: any error means "use the legacy resolver".
KFAR_VFS_ROOTSTAT   EQU     KFAR_SLOT0+4*46

; slot 47: root_listdir(name, dblk, buf, size) -> bytes written, or -errno.
; The directory-read conversion (apple/fgx#291), and the entry point that made
; a UFS machine able to verify anything: ls, pwd and shell globbing all need a
; directory and nothing else was giving them one.
;
; NEGATIVE IS -errno, POSITIVE IS A BYTE COUNT, which is dev_rw's convention
; and works for the same reason: no errno is 0 and no count is negative.  The
; errno is FINAL -- the core's hook negates it and returns it, there being no
; second enumerator to fall through to.
KFAR_VFS_ROOTLISTDIR EQU    KFAR_SLOT0+4*47

; slot 48: root_chdir(pid, name) -> 0 or errno.  The cwd port.
;
; IT SETS A VNODE AND NOT A STRING, which is the whole point: Reno's cwd is
; `u.u_cdir', a referenced vnode that namei's relative arm reads, and FGX's was
; a ProDOS-canonical UPPERCASE path.  A 2.11BSD volume's names are bytes, so
; the string could never name a directory on one.
;
; Same fall-through contract as slots 45-47: ENXIO means no root of ours and
; the caller carries on with the legacy cwd.
KFAR_VFS_ROOTCHDIR  EQU     KFAR_SLOT0+4*48
; The cwd's fork and exit halves (Reno kern_fork.c:272, kern_exit.c:139).  Both
; take pids and return nothing: they are bookkeeping on a pid-indexed table,
; not routing decisions, so unlike the four ROOT* slots above neither has an
; ENXIO arm for the core's hook to fall through on.
KFAR_VFS_CDIRFORK   EQU     KFAR_SLOT0+4*49 ; slot 49: root_cdirfork(ppid, cpid)
KFAR_VFS_CDIREXIT   EQU     KFAR_SLOT0+4*50 ; slot 50: root_cdirexit(pid)
KFAR_SYS_MODLOAD    EQU     KFAR_SLOT0+4*51 ; slot 51: SYS_MODLOAD (#110)
; Slots 52-54: the namespace operations against the mounted root, which the
; legacy resolver used to own.  unlink(2), mkdir(2) and rmdir(2) --
; apple/fgx#318's second half, landing with ProDOS's removal because the code
; they replace is what freed the core bytes they cost.
KFAR_VFS_ROOTUNLINK EQU     KFAR_SLOT0+4*52 ; slot 52: root_unlink(pid, path)
KFAR_VFS_ROOTMKDIR  EQU     KFAR_SLOT0+4*53 ; slot 53: root_mkdir(pid, path, mode)
KFAR_VFS_ROOTRMDIR  EQU     KFAR_SLOT0+4*54 ; slot 54: root_rmdir(pid, path)
; Slot 55: lseek(2) onto a root descriptor -- apple/fgx#322.  The seam carried
; vfs_read and vfs_write and nothing else, so a seek could not reach the
; offset the reads actually use however hard Fs_Lseek tried.
KFAR_VFS_LSEEK      EQU     KFAR_SLOT0+4*55 ; slot 55: vfs_lseek(pid,fd,off,whence,resultp)
KFAR_VFS_ROOTLSTAT  EQU     KFAR_SLOT0+4*56 ; slot 56: root_lstat(pid, path, sb)
                                            ;   stat's twin, NOFOLLOW; the only
                                            ;   thing separating the two
KFAR_VFS_ROOTREADLINK EQU   KFAR_SLOT0+4*57 ; slot 57: root_readlink(pid, path,
                                            ;   buf, count) -> count or -errno
KFAR_VFS_ROOTRENAME EQU     KFAR_SLOT0+4*58 ; slot 58: root_rename(pid, from, to)
                                            ;   TEN argument bytes -- two far
                                            ;   pointers and an int
KFAR_VFS_ROOTSYMLINK EQU    KFAR_SLOT0+4*59 ; slot 59: root_symlink(pid, target,
                                            ;   linkname, mode).  TWELVE bytes:
                                            ;   two far pointers and two ints
; statfs(2) and getfsstat(2) -- apple/fgx#329, df(1).  THE BUFFER IS THE
; CALLER'S AND IS NOT STAGED, which is what makes these two cheap: every other
; struct-returning slot here fills a core-bank scratch (_fsStatBuf) that the
; syscall then copies out, and `struct statfs' is 100 bytes against a core bank
; with a few hundred free.  vfs_statfs1 finishes with uio_copy, which is MVN
; and takes its destination bank from the pointer -- the same way uiomove
; already writes a user buffer -- so the core passes _Sys_CallerBank in the far
; pointer and no scratch exists to size.
KFAR_VFS_ROOTSTATFS EQU     KFAR_SLOT0+4*60 ; slot 60: root_statfs(pid, path,
                                            ;   sbp) -> 0 or errno.  TEN bytes,
                                            ;   rename's shape exactly
KFAR_VFS_GETFSSTAT  EQU     KFAR_SLOT0+4*61 ; slot 61: vfs_getfsstat(sbp,
                                            ;   bufsize) -> count.  SIX bytes:
                                            ;   one far pointer and an int

; slot 62: root_setattr(pid, path, follow, mode, uid, gid) -> 0 or errno.
; UFS 2.6 -- chmod(2) AND chown(2), one slot, because Reno's two syscalls are
; the same seven lines with a different vattr field set (kern/vfs_syscalls.c
; :1129 and :1197; vfs_setattr's header carries the argument).  VA_UNSET in a
; field means LEAVE IT, which is what lets one entry serve both.
;
; FOURTEEN ARGUMENT BYTES: a pid, an fcc pointer at four, and four ints.  The
; seam entry copies its arguments by hand and the count is the whole contract
; -- a short one is silent, and it cost a bisect on slot 45 to find that out.
KFAR_VFS_ROOTSETATTR EQU   KFAR_SLOT0+4*62

; slot 63: root_link(pid, target, linkname) -> 0 or errno.  UFS 2.6 -- link(2).
; TEN ARGUMENT BYTES, so 15,S; the offset is argbytes + 5 and the copy count
; and the closing drop move together.
;
; THE LAST SLOT OF THE ORIGINAL 64, and slots 36 and 37 are free above it if a
; sixty-fifth is wanted before KFAR_SLOT_COUNT is raised -- raising it costs
; four bytes a slot and one layout shift, which the patchsite generators
; regenerate, and it is not the kind of thing to do pre-emptively.
KFAR_VFS_ROOTLINK   EQU     KFAR_SLOT0+4*63

; slots 64 and 65: mount(2) and umount(2).  UFS 2.6, and they are 2.11BSD's
; INTERFACE over Reno's body -- see vfs_unmountdev's header for why the two
; ancestors disagree and which one userland forced.
;   64: vfs_mountat(pid, dvp, type, dir, flags, data) -> 0 or errno.  EIGHTEEN
;       argument bytes: a pid, a dvp, a type, an fcc pointer, flags, another
;       fcc pointer -- 2+4+2+4+2+4.  The core passes dvp as 0.
;   65: vfs_unmountdev(pid, spec, flags) -> 0 or errno.  EIGHT bytes.
KFAR_VFS_MOUNT      EQU     KFAR_SLOT0+4*64
KFAR_VFS_UNMOUNTDEV EQU     KFAR_SLOT0+4*65
; ftruncate(2), UFS 2.7.  It answered ENOSYS from _Fs_NoLegacy from the day
; the ProDOS write path was deleted; everything under it -- ufs_setattr's
; va_size arm and ufs_itrunc -- was already ported.
KFAR_VFS_FTRUNCATE  EQU     KFAR_SLOT0+4*66 ; slot 66: root_ftruncate(pid,fd,len)
; utimes(2), UFS 2.7 (apple/fgx#343).  It was the LAST path-taking syscall
; still dispatching into prodos.mod, so on a UFS root it simply failed.
KFAR_VFS_UTIMES     EQU     KFAR_SLOT0+4*67 ; slot 67: root_utimes(pid,path,at,mt)
; fchdir(2), UFS 2.7.  A libc stub until the far bank had room for the seam
; entry its own note said it needed.
KFAR_VFS_FCHDIR     EQU     KFAR_SLOT0+4*68 ; slot 68: root_fchdir(pid, fd)

; slot 69: root_access(pid, path, fmode) -> 0 or errno.  UFS 2.6 -- access(2).
; EIGHT argument bytes: an int, an fcc pointer, an int.
KFAR_VFS_ACCESS     EQU     KFAR_SLOT0+4*69

; fsync(2), apple/fgx#355.  It answered EIO out of the ProDOS FST for every
; regular file: `ufs_fsync' has been ported since 1.12 and VOP_FSYNC had two
; callers, both in a probe.  sync(2) has reached the inodes since apple/fgx#332
; -- vfs_sync -> vfs_sync1 -> ufs_sync -> ufs_iflushall -- but there was no
; path to ONE of them.
KFAR_VFS_FSYNC      EQU     KFAR_SLOT0+4*70 ; slot 70: root_fsync(pid, fd)

; slot 71: root_fstat(pid, fd, sb) -> 0 or errno, filling the core's
; `_fsStatBuf'.  fstat(2), apple/fgx#365.
;
; THE POINT IS THAT stat(2) AND fstat(2) STOP HAVING TWO ANSWERS.  Slot 46
; reaches a vnode by NAME; this one reaches a vnode by DESCRIPTOR, and both
; convert it through the one `vn_stat' -- which is Reno's arrangement
; (kern/vfs_syscalls.c and kern/kern_descrip.c calling one kern/vfs_vnops.c
; function).  While fstat answered from the FCB it reported st_ino as 0 because
; the FCB cannot know one, and `getwd(3)' -- which decides it has reached the
; root by comparing stat's inode against fstat's -- therefore never terminated.
;
; Any error is fstat's answer: every descriptor is a vnode, a socket or a pipe,
; and Reno panics on anything else (root_fstat).
KFAR_VFS_ROOTFSTAT  EQU     KFAR_SLOT0+4*71

; slot 72: root_sysctl(pid, uid, blk) -> 0 or errno.  sysctl(2), apple/fgx#410.
;
; `blk' NAMES THE CALLER'S BANK -- the six-argument signature does not fit the
; three-register syscall ABI, so the call arrives as a pointer to a block of
; words that the far bank reads and writes in place.  select(2) reaches the
; kernel the same way; root_sysctl.c's header states what the words mean.
;
; THE CREDENTIAL IS PASSED IN because this bank has no u-area to read.
; Upstream takes both from `u.' at the point of the check -- suser() for the
; write and `u.u_procp->p_pid != 1' for a LOWERING write -- and the core-bank
; stub reads them there instead.
KFAR_VFS_SYSCTL     EQU     KFAR_SLOT0+4*72

; --- slot 73: a module registers a console renderer (console_backend.s).
; A = table offset, Y = table bank; reached from SYS_KCALL's KSVC_CONBACKEND.
KFAR_CON_SETBACKEND EQU     KFAR_SLOT0+4*73

; slot 74: unp_nameop(pid, op, path, slotp) -> 0 or errno.  An AF_UNIX socket's
; NAME, bound and looked up -- 4.3BSD-Reno's unp_bind and unp_connect.
;
; IT IS HERE AND NOT IN net.mod BECAUSE namei IS NOT REACHABLE FROM A MODULE.
; namei lives in vfs.mod, the C that calls it is in this bank, and net.mod --
; which owns the AF_UNIX transport -- can reach neither directly.  So the whole
; nameidata dance is one far call made from a KSVC arm, rather than a walk driven
; step by step across three seams.
;
; `path' is _Sys_PathBuf and `slotp' is a core-bank word; the core-side stub
; supplies their bank, the way slot 71's does for _fsStatBuf.
KFAR_VFS_UNPNAME    EQU     KFAR_SLOT0+4*74

; --- the blocked-signal mask, slot 75 ---
; SYS_SIGSETMASK (#102) and SYS_SIGPROCMASK (#120) are one routine and it lives
; in the far bank: the core bank is at its ceiling and this is a cold syscall.
KFAR_SYS_SIGPROCMASK EQU    KFAR_SLOT0+4*75

; --- slot 76: setitimer(2), ITIMER_REAL (#121) ---
; Far-bank for the same reason as the mask above -- a cold syscall against a core
; bank that has been at its ceiling for months.  It reaches `_kAlarmTicks' and
; `_kAlarmReload', both kernel-bank globals in include/memmap.s, by `_cfpNNN'
; long addressing with the bank byte patched at Far_Init.
KFAR_SYS_SETITIMER  EQU    KFAR_SLOT0+4*76

; slot 77: vn_flock(fp, how) -> 0 or errno.  flock(2) on a vnode descriptor,
; which the core checks and resolves to its struct file first; the lock and its
; wait are kern_flock.c's, in ufs.mod.
KFAR_VFS_FLOCK      EQU    KFAR_SLOT0+4*77

; slot 78: vn_fsetattr(fp, mode, uid, gid) -> 0 or errno.  fchmod(2) and
; fchown(2) on a vnode descriptor, found by the core as flock's is; the rest is
; kern_fsetattr.c's.
KFAR_VFS_FSETATTR   EQU    KFAR_SLOT0+4*78

; --- the FGX binary loader, slots 39-42 (far-bank phase 3) ---
; loader.s left the core bank because the core bank ran out: 67 bytes from its
; ceiling with the tty campaign still to land.  The four names below are its
; whole inward surface -- every other loader symbol the core touches is a
; STATIC, read by a patched LDAL rather than called.
KFAR_LOAD_BINARY    EQU     KFAR_SLOT0+4*39 ; slot 39: Load_Binary.  X = path
                                            ;   offset IN THE CORE BANK (see
                                            ;   _FarSh_Fs_OpenCore for why that
                                            ;   is worth saying), A = bank
                                            ;   override, 0 = honour the header
KFAR_LOADER_ARGPAGES EQU    KFAR_SLOT0+4*40 ; slot 40: _Loader_ArgsExtraPages
KFAR_LOADER_STAGEARGS EQU   KFAR_SLOT0+4*41 ; slot 41: _Loader_StageArgs
KFAR_LA_SETSTAGEBASE EQU    KFAR_SLOT0+4*42 ; slot 42: _La_SetStageBase.  A =
                                            ;   base bytes 0-1, Y = byte 2:
                                            ;   where the staging stores land

; --- the loader's OUTPUTS, read from the core by patched LDAL ---
; Fixed offsets, like KFAR_VT_STATE above and for the same reason: a core LDAL
; needs an address at assemble time, and scraping the far listing to get one
; would make the build cyclic.  src/kernel/far/far.s carries an ERR per line
; that fails the build the moment a definition here stops matching the DUM.
KFAR_LD_OUTPUTS     EQU     $F800           ; == KFAR_LD_ORG's bank offset
KFAR_LD_ENTRY       EQU     KFAR_LD_OUTPUTS+0   ; 3 B: 24-bit entry address
KFAR_LD_USERBANK    EQU     KFAR_LD_OUTPUTS+3   ; 1 B: load bank
KFAR_LD_EXTRABANKS  EQU     KFAR_LD_OUTPUTS+4   ; 8 B: seg k's bank, owned
KFAR_LD_HEADER      EQU     KFAR_LD_OUTPUTS+12  ; 16 B: the cached FGX header
; The ids a set-id image adopts, $FFFF for "unchanged" (apple/fgx#416).  Read
; at the exec COMMIT and nowhere else: a load that fails must leave the
; caller's credentials exactly as they were.
KFAR_LD_SETUID      EQU     KFAR_LD_OUTPUTS+28  ; 2 B: effective uid, or $FFFF
KFAR_LD_SETGID      EQU     KFAR_LD_OUTPUTS+30  ; 2 B: effective gid, or $FFFF
KFAR_LD_TEXT        EQU     KFAR_LD_OUTPUTS+32  ; 1 B: shared-text index, 0 = none

;------------------------------------------------------------------------------
; THE BOOT PROGRAM'S CONSOLE FONT, staged into this bank before the kernel runs.
;
; A glass console needs glyphs before it can render one character, and Con_Init
; used to get them by OPENING /lib/fonts/default.fnt through the legacy ProDOS
; reader -- the last disk read in console init, running long before any module
; is loaded and therefore unservable by the VFS.  That single read is what a
; kernel booted from a 2.11BSD root halted on (`PANIC: cannot load default
; font'), and it is why the console could not follow the root filesystem.
;
; IT IS THE BOOT PROGRAM'S JOB, and that is the answer BSD does not supply:
; 2.11BSD drives serial terminals that own their own character generator, so
; there is no counterpart to port.  What there IS a counterpart for is the
; shape -- a boot program that loads the kernel and the pieces the kernel
; cannot fetch for itself, and hands them over at a fixed address.  Stage 2
; already reads both filesystems and already loads three kernel banks; the font
; is a fourth load into a bank it has open.
;
; NOT A COMPILED-IN BLOB.  These bytes come off the volume at every boot, so a
; different font is a different FILE and not a different kernel.  The image
; reserves the space (a DUM block, no bytes on disk) and stage 2 fills it.
;
; ABOVE KFAR_LD_OUTPUTS, in address space the far bank has never used: the code
; region ends at $EC40 and this costs it nothing.  The size is the FGXF v1 file
; -- 48-byte header plus the mode's glyph block -- rounded to the page, so the
; loader can write it with a page-aligned destination like every other load.
KFAR_BOOT_FONT      EQU     $F900           ; the staged FGXF file, header first
KFAR_BOOT_FONT_MAX  EQU     $0400           ; 1,024 B reserved; 808 in use today
KFAR_BOOT_FONT_GLYPHS EQU   KFAR_BOOT_FONT+48   ; past the header
