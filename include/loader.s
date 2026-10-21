;==============================================================================
; loader.s - FGX1 binary format constants + syscall ABI numbers
;
; Source of truth for:
;   - FGX1 header field offsets (mirrors §3.4 of the program-execution spec)
;   - Syscall numbers (mirrors §3.3 of the spec; BSD-numbered where applicable)
;   - User-space bank constants (FGX_USER_BASE = $0A; bank-tiled per-task)
;==============================================================================

;------------------------------------------------------------------------------
; FGX1 binary header layout.  Total size = 16 bytes; payload follows at +16.
;------------------------------------------------------------------------------
FGX1_MAGIC      EQU     $31584746           ; 'FGX1' little-endian: $46 $47 $58 $31
FGX1_HEADER_SZ  EQU     16

FGX1_OFF_MAGIC  EQU     0                   ; 4 bytes: 'FGX1'
FGX1_OFF_LOAD   EQU     4                   ; 3 bytes: 24-bit load address
FGX1_OFF_PAD    EQU     7                   ; 1 byte: reserved, must be 0
FGX1_OFF_ENTRY  EQU     8                   ; 2 bytes: entry offset from load
FGX1_OFF_TEXT   EQU     10                  ; 2 bytes: text size (bytes to copy)
FGX1_OFF_BSS    EQU     12                  ; 2 bytes: bss size (bytes to zero)
FGX1_OFF_STACK  EQU     14                  ; 1 byte: stack pages hint (0=default)
FGX1_OFF_FLAGS  EQU     15                  ; 1 byte: future flags

;------------------------------------------------------------------------------
; FGX2 binary header layout (multi-bank loader, Phase 2 slice 2.2).  Same
; 16-byte header size as FGX1 + an n*8-byte segment table starting at
; file offset 16.  Slice 2.2 supports n_segments=1 only; n_segments>1
; lands in slice 2.3 alongside cross-bank linking.  See
; docs/superpowers/specs/2026-05-18-fgx-multi-bank-loader-design.md.
;------------------------------------------------------------------------------
FGX2_MAGIC      EQU     $32584746           ; 'FGX2' little-endian: $46 $47 $58 $32
FGX2_HEADER_SZ  EQU     16                  ; same size as FGX1; segments follow

FGX2_OFF_MAGIC      EQU 0                   ; 4 bytes: 'FGX2'
FGX2_OFF_RESERVED1  EQU 4                   ; 2 bytes: reserved (0)
FGX2_OFF_NSEGS      EQU 6                   ; 1 byte: 1..8 segments
FGX2_OFF_NDATASEG   EQU 7                   ; 1 byte: which segment holds globals
FGX2_OFF_ENTRY      EQU 8                   ; 2 bytes: entry offset within data
                                            ;          segment's bank
FGX2_OFF_FLAGS      EQU 10                  ; 1 byte: bit 0 = STRICT_SINGLE_BANK
FGX2_FLAG_LIB       EQU $02                 ; flags bit 1: a shared library (fgx_ld), not a program
FGX2_OFF_RELOCS     EQU 11                  ; 2 bytes: reloc_count.  Phase 3.1
                                            ;          slice A: was reserved.
                                            ;          0 = no relocs (FGX1-shape
                                            ;          single-bank binaries).
FGX2_OFF_RESERVED2  EQU 13                  ; 1 byte: reserved (0)
FGX2_OFF_STACK      EQU 14                  ; 1 byte: bank-0 hw-stack pages hint,
                                            ;         SHARED with FGX1_OFF_STACK
                                            ;         (=14) so the loader's
                                            ;         Task_AllocStack path honors
                                            ;         it for both formats.  0 =
                                            ;         loader default (1 page).
                                            ;         Written by fgx_ld.py from
                                            ;         the fcc frame call graph
                                            ;         (P3-3 3.2).
FGX2_OFF_SOFTBANK   EQU 15                  ; 1 byte: DEDICATED banks wanted for
                                            ;         the soft-frame stack (bank-0
                                            ;         campaign 1.3).  0 = none, and
                                            ;         every pre-campaign binary
                                            ;         reads 0 because this byte was
                                            ;         `reserved`.  Written by
                                            ;         fgx_ld.py, DERIVED from the
                                            ;         presence of a `_SOFTSIZE EQU`
                                            ;         in the binary's own assembly,
                                            ;         so the flag cannot disagree
                                            ;         with the codegen that needs
                                            ;         it.  The loader grants the
                                            ;         bank and seeds _fcc_sfp to
                                            ;         bank:$FFFE before entry.

;------------------------------------------------------------------------------
; FGX3 (P3-5 I1): byte-identical layout to FGX2 — same 16-byte header, segment
; table, segment data, and reloc entries — plus a MANDATORY ABI stamp at
; header byte 13 (reserved-0 in FGX2).  Loads through the _LoadFGX2 code path;
; the magic bump is the clean-break marker: a pre-P3 kernel rejects the
; unknown magic natively (ENOEXEC), and this loader rejects a stale stamp, so
; a post-flip binary and a pre-flip kernel can never silently mis-run each
; other.  Keep in sync: toolchain/src/ld/fgx_ld.py FGX3_MAGIC / ABI_OFF /
; FGX_ABI_CURRENT.
;------------------------------------------------------------------------------
FGX3_MAGIC      EQU     $33584746           ; 'FGX3' little-endian: $46 $47 $58 $33
FGX3_OFF_ABI    EQU     13                  ; 1 byte: abi_version (MANDATORY)
FGX_ABI_CURRENT EQU     2                   ; v2 = post-Phase-3 (32-bit ptr
                                            ; model, hw stack, kernel ABI v2)

FGX2_MAX_SEGS       EQU 8                   ; spec cap; honored at parse time.
                                            ; TCB_BankList has 8 rows, one per
                                            ; segment, so a ninth segment would
                                            ; hold a bank exit never frees.
                                            ; Going past 8 needs the TCB
                                            ; restructure (TCB_SIZE is pinned
                                            ; at 64 B by an ERR).
FGX2_SEGTAB_ENTRY_SZ EQU 8                  ; bytes per segment table entry

FGX2_SEG_SIZE       EQU 0                   ; 2 bytes: bytes to copy from file
FGX2_SEG_BSS        EQU 2                   ; 2 bytes: bytes to zero after text
FGX2_SEG_KIND       EQU 4                   ; 1 byte: 0=CODE, 1=DATA, 2=RODATA;
                                            ;   the loader refuses any other
                                            ;   kind (ENOEXEC)
FGX2_SEG_FLAGS      EQU 5                   ; 1 byte: flags, below
FGX2_SEG_RESERVED   EQU 6                   ; 2 bytes: reserved (0)

; FGX2_SEGF_PLACE: every absolute address that names this segment carries an
; offset relocation (FGX2_RELOC_ADDOFF), so the loader may put the segment at
; a page offset in a bank instead of at $0000.  fgx_ld sets it for a segment
; whose link listed its own addresses (toolchain/src/ld/fgx_offrel.py).
FGX2_SEGF_PLACE     EQU $01

;------------------------------------------------------------------------------
; Segment kinds.
;------------------------------------------------------------------------------
SEG_KIND_CODE       EQU 0
SEG_KIND_DATA       EQU 1
SEG_KIND_RODATA     EQU 2

;------------------------------------------------------------------------------
; FGX2 relocation entries (Phase 3.1 — cross-bank linking).  Sit in the
; file AFTER all segment data, count is FGX2_OFF_RELOCS in the header.
;
; Generic shape: "write bank-for-segment[tgt_seg] into segment[src_seg]:offset".
; Covers two patch patterns the compiler emits:
;   1. JSL bank byte: caller's JSL placeholder operand has bank = 0; reloc
;      with tgt_seg = callee's segment patches it to the callee's runtime
;      bank.  Offset points at the JSL operand's bank byte (opcode + 3).
;   2. LDA #data_bank immediate: callee prologue does `LDA #imm8; PHA; PLB`
;      to switch DBR to the data segment's bank.  Reloc with tgt_seg =
;      n_data_segment patches the immediate byte.  Offset points at the
;      LDA's operand byte (opcode + 1).
;------------------------------------------------------------------------------
FGX2_RELOC_ENTRY_SZ EQU 4                   ; bytes per reloc entry
FGX2_RELOC_BATCH    EQU 64                  ; reloc entries per streamed batch.
                                            ; The loader applies the reloc table
                                            ; in batches of this size through a
                                            ; FGX2_RELOC_BATCH*4 = 256 B buffer,
                                            ; so reloc_count scales to the 16-bit
                                            ; header field (no cap, no big buffer).
                                            ; Big multi-bank C ports (vi: >1000
                                            ; relocs) need this — see SP5.

FGX2_RELOC_SRC_SEG  EQU 0                   ; 1 byte: segment containing patch
FGX2_RELOC_OFFSET   EQU 1                   ; 2 bytes: offset within src seg
FGX2_RELOC_TGT_SEG  EQU 3                   ; 1 byte: segment whose bank goes

; FGX2_RELOC_ADDOFF: bit 7 of the target byte.  Set, the entry is an offset
; relocation: add segment (tgt & $7F)'s load offset to the 16-bit word at
; src_seg:offset, instead of writing its bank into one byte.  A loader that
; predates it reads a segment number past the image's count and refuses the
; image with ENOEXEC (apple/fgx#522).
FGX2_RELOC_ADDOFF   EQU $80

;------------------------------------------------------------------------------
; Syscall numbers (subset for slice 1).  See spec §3.3 for the full v1 table.
; Numbers follow 2.11BSD <sys/syscall.h> where the call exists in BSD.
;------------------------------------------------------------------------------
; Exit status a binary uses when fcc's prologue stack guard kills it
; (_fcc_stkoflow, toolchain/lib/fcc_runtime.s; 128+SIGABRT convention).  Shared
; here rather than duplicated because the KERNEL reports it -- see _Sys_Exit.
TASK_EXIT_STKOFLOW EQU  134
TASK_EXIT_SFOFLOW EQU   135                 ; SOFT-frame (data-bank) overflow --
                                            ; a distinct status only so the two
                                            ; detectors are tellable apart in dmesg
TASK_EXIT_HEAPFULL EQU  136                 ; sbrk(2) refused and the caller is a
                                            ; port that does not check.  libc's
                                            ; public sbrk() exits with this rather
                                            ; than returning -1: 2.11BSD's setbrk
                                            ; does `brkend = sbrk(incr) + incr`
                                            ; unchecked, so -1 makes brkend
                                            ; garbage and the shell writes past
                                            ; its arena -- corruption that
                                            ; presents as a hang.  A named death
                                            ; is strictly better.  malloc keeps
                                            ; the checkable path (_sbrk_soft) so
                                            ; it can still return NULL.  #13.

; Lowest offset a soft frame may occupy in its own bank.  Page 0 is left
; unused so a runaway recursion trips the guard instead of wrapping into a
; pointer that looks valid.  This REPLACES the FCC_SOFT_FLOOR data-bank reserve:
; partitioning one bank between the soft stack and bsh's stak arena could not be
; made both deep enough and safe -- capping the break makes sbrk fail, and
; 2.11BSD's setbrk never checks its return, so the cap corrupted the shell
; instead of bounding it (measured 2026-08-02, apple/fgx#12).  A dedicated bank
; removes the contention rather than dividing it.
FCC_SOFT_BOTTOM EQU     $0100
SYS_EXIT        EQU     1                   ; exit(status): A.lo=status -> does not return
SYS_FORK        EQU     2                   ; fork() -> parent: A=child pid; child: A=0
SYS_READ        EQU     3                   ; read(fd,buf,len): A=fd X=buf(own bank) Y=len -> A=bytes (0=EOF); C=1 for fd>0, C=0+A=errno on bad fd
SYS_WRITE       EQU     4                   ; write(fd,buf,len): A=fd X=buf Y=len -> A=bytes_written; C=1 ok
SYS_OPEN        EQU     5                   ; open(path,flags): A=path(own-bank) X=O_* flags Y=mode (creating opens; umask applied) -> C=1+A=fd; C=0+A=errno
SYS_CLOSE       EQU     6                   ; close(fd): A=fd -> C=1 ok; C=0+A=errno
SYS_WAIT        EQU     7                   ; wait(status): X=status_buf(own-bank) -> A=exited pid; C=0+A=ECHILD if no children
SYS_UNLINK      EQU     10                  ; unlink(path): A=path -> C=1 ok; C=0+A=errno
SYS_EXECVE      EQU     11                  ; execve(path,argv,envp): A=path X=argv Y=envp -> does not return on success
SYS_CHDIR       EQU     12                  ; chdir(path): A=path -> C=1 ok; C=0+A=errno
SYS_BRK         EQU     17                  ; brk(2), fork train Stage S.  A=the NEW
                                            ;   break offset (absolute, as BSD's
                                            ;   syscall has always taken it -- libc
                                            ;   does sbrk's addition), Y.lo=the sbrk
                                            ;   bank.  Returns C=1 + A=OLD break +
                                            ;   Y=sbrk bank (the heap descriptor lives
                                            ;   at dataBank:$FFFA/$FFFC/$FFFE; grown
                                            ;   spans are NOT zero-filled, see #361).
                                            ;   C=0 + A=errno: ENOMEM below HEAP_BASE
                                            ;   (`end') or past HEAP_LIM, EINVAL for
                                            ;   a bank that is not this task's.
                                            ;   libc layers brk()/sbrk() on this.
SYS_STAT        EQU     18                  ; stat(path,buf): A=path X=stat_buf(own-bank) -> C=1 ok; C=0+A=errno
SYS_LSEEK       EQU     19                  ; lseek: A.lo=fd A.hi=whence X=off.lo16 Y.lo=off.hi8 -> C=1+A=newpos.lo16 Y=newpos.hi8; C=0+A=errno
SYS_GETPID      EQU     20                  ; getpid() -> A=pid
; 21/22 RESERVED — 2.11BSD mount(2)/umount(2), held for the UFS campaign (see
; docs/history/plans/2026-07-21-unix-fs-second-fst-plan.md §3.2).  Freed
; 2026-07-28 by moving getuid/getgid onto their BSD numbers (24/47); the move
; cost nothing because nothing called 21/22 — libc's getuid() was a compiled-in
; `return 0` that never issued the syscall.  (Column-0 comment on purpose: an
; indented one would be swept into SYS_GETPID's generated description.)
SYS_SETUID      EQU     23                  ; setuid(uid): A=uid -> C=1+A=0; C=0+A=EPERM.
                                            ;   root sets real+effective+saved; non-root
                                            ;   may set only the effective id, and only
                                            ;   to its real or saved-set id (POSIX rule).
SYS_GETUID      EQU     24                  ; getuid() -> A=REAL uid, Y=EFFECTIVE uid,
                                            ;   C=1.  Both, as V7/2.11BSD getuid returns
                                            ;   r0/r1 — that is why there is no
                                            ;   SYS_GETEUID: libc's geteuid() issues this
                                            ;   and reads the Y return.  0/0 for a
                                            ;   boot-context caller with no u-area.
SYS_SETGID      EQU     25                  ; setgid(gid): same rule on the gid triple.
                                            ;   FGX-local number — BSD's setgid=46 is
                                            ;   spent on SYS_VFORK.
SYS_SETEUID     EQU     26                  ; seteuid(uid): effective only, same
                                            ;   permission rule.  FGX-local.
SYS_SETEGID     EQU     27                  ; setegid(gid): effective only.  FGX-local.
SYS_FSTAT       EQU     28                  ; fstat(fd,buf): A=fd X=stat_buf -> C=1 ok, C=0+A=errno (EBADF). Same stat struct as SYS_STAT
SYS_KILL        EQU     37                  ; kill(pid,sig): A=pid X=sig -> C=1 ok
SYS_GETPPID     EQU     39                  ; getppid() -> A=ppid
; 40 is unused: isatty(3) is a libc function over ioctl(fd, TIOCGETP).
SYS_DUP         EQU     41                  ; dup(fd): A=fd -> A=newfd (lowest free); C=1 ok, C=0+A=errno (EBADF/EMFILE)
SYS_PIPE        EQU     88                  ; pipe(fd[2]): X=&fd[2] -> fd[0]=read fd[1]=write; C=1 ok, C=0+A=errno (ENFILE/EMFILE/ENOMEM)
SYS_DUP2        EQU     89                  ; dup2(old,new): A=old X=new -> A=new (closes new if open); C=1 ok, C=0+A=errno (EBADF/EMFILE)
SYS_SLOTSCAN    EQU     90                  ; FGX: copy the boot slot-scan table into a
                                            ;   caller buffer.  A = buf offset (caller
                                            ;   bank), X = bufsize bytes.  Returns C=1 +
                                            ;   A = bytes written (50), or C=1 + A=0 if
                                            ;   bufsize < 50.  byte0 = detected W5100 slot
                                            ;   (0=none); bytes 1..49 = 7 records of
                                            ;   {flags, sig[6]} for slots 1..7.
SYS_REALLOC     EQU     91                  ; userland-libc: resize a SYS_MALLOC block,
                                            ;   preserving contents.  A.lo = old bank,
                                            ;   X = old offset, Y = new size (bytes).
                                            ;   NULL old ptr (bank=0,off=0) -> malloc.
                                            ;   Returns C=1 + A.lo = bank, Y = offset
                                            ;   (offset in Y not X: dispatcher exit
                                            ;   clobbers handler-return X); C=0 + A =
                                            ;   errno (ENOMEM: old block left intact,
                                            ;   per the C realloc contract).
SYS_MKDIR       EQU     92                  ; mkdir(path,mode): A = path (caller bank),
                                            ;   X = mode, masked by the umask as Reno
                                            ;   does.  Returns C=1 + A=0, or C=0 +
                                            ;   A=errno (EEXIST/ENOSPC/ENOTDIR/ENOENT/
                                            ;   EIO).
SYS_UTIME       EQU     93                  ; utimes(path,times): A = path offset, X =
                                            ;   offset of two 32-bit epoch times (atime,
                                            ;   mtime), both in the caller's data bank.
                                            ;   Returns C=1 + A=0, or C=0 + A=errno
                                            ;   (ENOENT/EIO).
SYS_RMDIR       EQU     94                  ; rmdir(path): A = path (caller bank).  Returns C=1 + A=0, or
                                            ;   C=0 + A=errno (ENOTDIR/ENOTEMPTY/ENOENT/
                                            ;   EIO/EBUSY).
SYS_RENAME      EQU     95                  ; rename(from,to): A = offset of an argument
                                            ;   block, +0 from and +4 to, each a far
                                            ;   pointer.  C=1+A=0, or C=0 + A=errno
                                            ;   (EXDEV across filesystems).
SYS_MALLOC32    EQU     96                  ; userland-libc: 32-bit-size malloc (train-2
                                            ;   M-4).  A = size lo16, X = size hi16.
                                            ;   Returns like SYS_MALLOC: C=1 + A.lo=bank
                                            ;   + Y=offset (offset 0 = dedicated MM
                                            ;   block), or C=0 + A=errno.  SYS_MALLOC
                                            ;   (#62) zero-extends into the same core.
; 42 was SYS_GETCWD (FGX-specific).  Retired: getwd(3) is 2.11BSD's own
; tree walk in libc, and the kernel keeps no cwd string (apple/fgx#344).
SYS_POSIX_SPAWN EQU     43                  ; FGX-specific: posix_spawn(path,argv,envp)
                                            ; (slice-3: argv/envp are caller-bank
                                            ;  ptrs to NULL-term arrays of 16-bit
                                            ;  ptrs.  Slot 45 retired.)
SYS_POSIX_SPAWNX EQU    44                  ; FGX: posix_spawn + file_actions.
                                            ; A=path, X=argv, Y=file_actions ptr
                                            ; (NULL = no actions, equivalent to
                                            ;  SYS_POSIX_SPAWN; envp = empty).
                                            ; Actions are applied to the *child's*
                                            ;  fd table only -- parent's fds are
                                            ;  never touched.  Matches the POSIX
                                            ;  posix_spawn_file_actions_t shape.
SYS_VFORK       EQU     46                  ; vfork(): the child shares the parent's
                                            ;   whole image + stack; parent blocks
                                            ;   (WCHAN_VFORK) until the child execve()s
                                            ;   or _exit()s.  Child: C=1+A=0; parent (on
                                            ;   resume): C=1+A=child pid.  (BSD's number
                                            ;   66 is squatted by SYS_POLLKEY, so
                                            ;   FGX-local 46.)
SYS_GETGID      EQU     47                  ; getgid() -> A=REAL gid, Y=EFFECTIVE gid,
                                            ;   C=1.  Same two-value return and
                                            ;   no-u-area rule as SYS_GETUID; getegid()
                                            ;   reads the Y return.
SYS_SIGNAL      EQU     48                  ; signal(sig, handler) — slice-2 stub

;------------------------------------------------------------------------------
; file_action struct layout (for SYS_POSIX_SPAWNX).
;
; List is an array of 6-byte entries in caller bank, terminated by op=0.
;
;   offset  field   meaning per op
;   0       op      0=END (terminator) | 1=OPEN | 2=CLOSE | 3=DUP2
;   1       fd      target fd in child (OPEN/CLOSE/DUP2 dst)
;   2..3    arg1    OPEN: own-bank ptr to NUL-term path
;                   DUP2: srcFd (low byte)
;                   CLOSE: ignored
;   4..5    arg2    OPEN: O_* flags (O_CREAT/WRONLY/RDONLY/APPEND/TRUNC)
;                   DUP2/CLOSE: ignored
;------------------------------------------------------------------------------
FA_OP_END       EQU     0
FA_OP_OPEN      EQU     1
FA_OP_CLOSE     EQU     2
FA_OP_DUP2      EQU     3
FA_OP_DETACH    EQU     4                   ; child gives up its controlling
                                            ; terminal and process group before
                                            ; the opens that follow: TIOCNOTTY,
                                            ; expressed in spawn's vocabulary.
                                            ; fd/arg1/arg2 all ignored.
                                            ;
                                            ; SPAWN IS A FUSED fork+exec, so the
                                            ; file-actions walk is the only place
                                            ; a caller can run code in the child
                                            ; -- and BSD's session daemons detach
                                            ; exactly there, between fork and
                                            ; exec (telnetd.c:266-271).  A recipe
                                            ; that leads with DETACH and then
                                            ; OPENs the line is that sequence.
                                            ; Without it, once spawn inherits the
                                            ; process group (apple/fgx#60), a
                                            ; getty spawned onto a pty arrives
                                            ; already-grouped and ttyopen's
                                            ; `p_pgrp == 0` claim never fires.
FA_SIZE         EQU     6                   ; bytes per entry
SYS_LISTDIR     EQU     49                  ; FGX-specific: listdir(path, buf, sz)
SYS_GETKEY      EQU     50                  ; FGX-specific: read one raw key from
                                            ; console (blocking, no echo, no line
                                            ; discipline).  Used by userland line
                                            ; editors that want arrow keys / ctrl
                                            ; sequences themselves.
SYS_UPTIME      EQU     51                  ; FGX-specific: copy 6-byte boot
                                            ; wall-clock (ReadTimeHex layout)
                                            ; into caller-bank buf at A.  Userland
                                            ; pairs with its own ReadTimeHex call
                                            ; to compute time-since-boot.
SYS_TICKS       EQU     52                  ; FGX-specific: return 32-bit kernel
                                            ; tick counter (60 Hz).  A = lo16,
                                            ; X = hi16 on return; C=1 always.
                                            ; Atomic w.r.t. VBL IRQ.
SYS_KSTAT       EQU     53                  ; FGX-specific diagnostic: copy a
                                            ; 16-byte kernel-stat struct into the
                                            ; caller-bank buffer at A.  Layout:
                                            ;   [0..3]   total Kmalloc count
                                            ;   [4..7]   total Kfree   count
                                            ;   [8..11]  cur bytes USED
                                            ;   [12..15] total Blk_Read count
                                            ; All four are little-endian 32-bit.
SYS_BORDER      EQU     55                  ; FGX-specific: set IIgs border color.
                                            ; A.lo = color index 0..15 (writes the
                                            ; low nibble of $E0C034; high nibble
                                            ; preserved).
SYS_SETPAL      EQU     56                  ; FGX-specific: rewrite palette 0's
                                            ; fg or bg slots to a 12-bit RGB.
                                            ; A.lo = role (0=fg, 1=bg).
                                            ; X    = 12-bit RGB (bits 11..8 R,
                                            ;        7..4 G, 3..0 B).
                                            ; fg writes palette 0 slots 3/7/11/15;
                                            ; bg writes slots 0/4/8/12.  Takes
                                            ; effect at the next SHR scanout.
SYS_FONTLOAD    EQU     57                  ; FGX-specific: load a bitmap font
                                            ; from a .FNT file.
                                            ; A = caller-bank path offset
                                            ;     (NUL-term).
                                            ; On success: rebuild PreExp cache,
                                            ;     repaint screen, set
                                            ;     CurrentFontName from the path
                                            ;     basename (lowercased, .fnt
                                            ;     extension stripped).
                                            ; Returns: C=1+A=0 ok; C=0+A=errno
                                            ;     on Fs_Open/read failure or
                                            ;     FGXF magic/version mismatch.
SYS_FONTREVERT  EQU     58                  ; FGX-specific: revert to the
                                            ; built-in default font and clear
                                            ; CurrentFontName.  No args; C=1.
SYS_FONTNAME    EQU     59                  ; FGX-specific: copy the current
                                            ; font name (NUL-term, "" = default)
                                            ; into a caller-bank buffer.
                                            ; A = caller-bank buf offset.
                                            ; X = buf size (bytes).
                                            ; Returns: C=1 + A = bytes copied
                                            ;     including NUL.
SYS_DMESG       EQU     60                  ; FGX-specific: copy kernel log
                                            ; ring buffer into a caller-bank
                                            ; buffer.  A = caller-bank buf
                                            ; offset.  X = max bytes to copy.
                                            ; Returns: C=1 + A = bytes copied
                                            ; (in chronological order; oldest
                                            ; bytes first if the ring has
                                            ; wrapped).  Pairs with /bin/dmesg.
SYS_MEMINFO     EQU     61                  ; FGX-specific diagnostic: query
                                            ; Kmalloc/Kfree state.  A.lo =
                                            ; subcmd; X = caller-bank buf
                                            ; offset; Y = buf size in bytes.
                                            ; Subcmds:
                                            ;   0 = type stats (8 × 16 B)
                                            ;   1 = arena stats (N × 16 B)
                                            ;   2 = chunk walk (per-chunk 8 B)
                                            ;   3 = retired (EINVAL; the pool
                                            ;       is vm.coremap)
                                            ;   4 = guard audit (corrupt chunks)
                                            ;   5 = Memory Manager block table
                                            ;       (8 B rows)
                                            ;   6 = Memory Manager totals (3
                                            ;       longs)
                                            ; Returns: C=1 + A = bytes written;
                                            ; C=0 + A = errno (EINVAL on bad
                                            ; subcmd).  Pairs with vmstat -m,
                                            ; -c and -g.
SYS_ALARM       EQU     64                  ; vi-port slice 3: alarm(seconds).
                                            ; A.lo = seconds; 0 cancels any
                                            ; pending alarm.  Returns A =
                                            ; previous alarm's remaining
                                            ; seconds (0 if none).  SIGALRM
                                            ; gets delivered at the next
                                            ; syscall return after the timer
                                            ; expires.
SYS_MALLOC      EQU     62                  ; userland-libc: allocate.  A =
                                            ; size (16-bit, bytes).  Returns
                                            ; C=1 + A.lo = bank, Y = offset;
                                            ; C=0 + A = ENOMEM if heap full
                                            ; or EINVAL on size=0.  Block is
                                            ; tagged M_ANON.  Lives in one of
                                            ; the kernel heap banks ($07-$09);
                                            ; userland uses LDAL/STAL to access.
                                            ; Offset returned in Y, NOT X,
                                            ; because dispatcher exit clobbers
                                            ; handler-return X (see memory note
                                            ; feedback_syscall_dispatcher_x_
                                            ; clobber_at_exit).
SYS_FREE        EQU     63                  ; userland-libc: release a block
                                            ; from SYS_MALLOC.  A.lo = bank,
                                            ; X = offset.  Returns C=1 ok;
                                            ; C=0 + A = EFAULT if the ptr
                                            ; doesn't name a live allocation.
SYS_IOCTL       EQU     65                  ; FGX-specific: device control on a fd.
SYS_POLLKEY     EQU     66                  ; FGX-specific: non-blocking key poll.
                                            ; C=1 + A=key if one is queued, else C=0.
                                            ;   A.lo = fd, X = cmd, Y = arg-ptr
                                            ;   lo16; arg-ptr bank pushed before
                                            ;   COP.  Returns C=1 (A=0) ok;
                                            ;   C=0 (A = errno: ENOTTY for unknown
                                            ;   cmd, EBADF for unknown fd).
                                            ;   Routes through the FCB's FST FOP
                                            ;   table (FOP_Ioctl).  Non-chardev
                                            ;   FSTs return ENOTTY.
SYS_GETFSSTAT   EQU     67                  ; FGX: copy struct statfs[] for all
                                            ; online mounts into a caller buffer
                                            ; (BSD getfsstat).  A = buf offset
                                            ; (caller bank), X = bufsize bytes,
                                            ; Y = flags (ignored).  Returns C=1 +
                                            ; A = mount count written.
SYS_MM_ALLOC    EQU     68                  ; FGX: large Memory-Manager allocation
                                            ; via _NewHandle (MAY span banks; for
                                            ; the resident NTP module).  A = size
                                            ; lo16, X = size hi16.  Returns C=1 +
                                            ; A.lo = handle bank, Y = handle offset
                                            ; (deref the handle for the 24-bit
                                            ; base); C=0 + A = ENOMEM.  Block attr
                                            ; $C008 = locked|fixed|noSpec, NO
                                            ; attrNoCross so it can be >64 KB
                                            ; multi-bank.
SYS_MM_FREE     EQU     69                  ; FGX: release a SYS_MM_ALLOC block.
                                            ; A.lo = handle bank, X = handle offset
                                            ; (_DisposeHandle).  Returns C=1.
SYS_IFCONFIG    EQU     70                  ; FGX net: get/set an interface record.
                                            ; A = ifreq offset, X = op (IFC_*),
                                            ; caller DBR = ifreq bank.  See
                                            ; ifconfig_sys.s / include/ifnet.s.
SYS_SOCKET      EQU     71                  ; BSD socket(domain,type,proto): A=domain,
                                            ; X=type, Y=proto -> A=fd.  See socket.s.
SYS_BIND        EQU     72                  ; bind(fd, sockaddr_in*, len)
SYS_SENDTO      EQU     73                  ; sendto(fd, argblk*)  [argblk: see socket.s]
SYS_RECVFROM    EQU     74                  ; recvfrom(fd, argblk*) (non-blocking)
SYS_SETSOCKOPT  EQU     75                  ; setsockopt(fd, level, optname, val*, len)
SYS_CONNECT     EQU     76                  ; connect(fd, sockaddr_in*, len)  [TCP]
SYS_SEND        EQU     77                  ; send(fd, argblk*)  [buf,len,flags]
SYS_RECV        EQU     78                  ; recv(fd, argblk*)  (blocking; MSG_DONTWAIT)
SYS_YIELD       EQU     79                  ; yield() — cooperative reschedule (no args)
SYS_SETPGID     EQU     80                  ; setpgid(pid, pgid) — job control.
                                            ;   A = pid (0 = caller), X = pgid
                                            ;   (0 = use pid).  C=1 + A=0 ok;
                                            ;   C=0 + A = ESRCH (no such pid).
SYS_GETPGRP     EQU     81                  ; getpgrp(pid) — THAT process's
                                            ;   group, as 2.11BSD's does.
                                            ;   A = pid (0 = caller).
                                            ;   C=1 + A = pgrp;
                                            ;   C=0 + A = ESRCH (no such pid).
SYS_WAITPID     EQU     82                  ; waitpid(pid, *status, options).
                                            ;   A = pid (-1 = any child, >0 =
                                            ;   that pid), X = status-ptr offset
                                            ;   (0 = none), Y = options.  C=1 +
                                            ;   A = pid (reaped/stopped) or 0
                                            ;   (WNOHANG, nothing waitable);
                                            ;   C=0 + A = ECHILD.
SYS_NANOSLEEP   EQU     83                  ; nanosleep(ticks) — block the caller for
                                            ;   A = duration in 60 Hz ticks (16-bit).
                                            ;   Idle-blocks via _sleep(WCHAN_TIMER);
                                            ;   C=1 + A=0 when the deadline passes;
                                            ;   C=0 + A = EINTR if a signal woke it
                                            ;   first.  A=0 returns immediately.
SYS_LISTEN      EQU     84                  ; listen(fd, backlog) — TCP server: OPEN the
                                            ;   bound socket in TCP mode + LISTEN.  A=fd,
                                            ;   X=backlog (ignored, W5100 single-socket).
                                            ;   C=1 + A=0 ok; C=0 + A=errno.
SYS_ACCEPT      EQU     85                  ; accept(fd) — block until a peer connects;
                                            ;   A=listen fd.  C=1 + A = new connection fd
                                            ;   (the listener's hw socket; listenfd is
                                            ;   detached); C=0 + A=errno (EINTR on ^C).
SYS_SOUND_CLAIM EQU     86                  ; sound_claim() — caller claims the DOC, so the
                                            ;   kernel runs Sound_StopDoc when the caller
                                            ;   TERMINATES (audio stops on kill, keeps
                                            ;   playing when backgrounded).  C=1 + A=0.
SYS_PROCS       EQU     87                  ; procs(buf,max) — process enumeration for ps
                                            ;   and w; fills buf with PROCINFO_SIZE
                                            ;   records {pid,ppid,pgid,state,name[16],
                                            ;   stksize,stkhwm,arena_used,arena_free,
                                            ;   heaphwm,ttyname[8]} (include/kernel.s
                                            ;   PI_*), returns count. C=1 + A=count.
SYS_FSYNC       EQU     97                  ; train-3 F4: fsync(fd) — force this
                                            ; file's data + metadata to disk NOW.
                                            ; A.lo = fd.  C=0+A=EBADF/EIO.
SYS_SYNC        EQU     98                  ; train-3 F4: sync() — commit every
                                            ; open file's dirty state + bitmap.
                                            ; Always C=1 (errors latch per-FCB).
SYS_SELECT      EQU     99                  ; select(nfds,rd,wr,ex,timeout) via a
                                            ; libc-marshalled argblk (A.lo=off).
                                            ; C=1+A=ready count / C=0+A=errno.
SYS_SHUTDOWN    EQU     100                 ; shutdown(fd, how): A=fd, X=how.  TCP
                                            ; half-close — SHUT_WR/RDWR send FIN
                                            ; (CR_DISCON, socket stays FIN_WAIT so
                                            ; recv still drains); SHUT_RD = no-op.
                                            ; C=1 ok / C=0+A=EBADF/ENOTSOCK.
SYS_SIGSETMASK  EQU     102                 ; sigsetmask(mask): A=lo16, X=hi16 of
                                            ; the 32-bit BSD signal mask (bit s-1
                                            ; blocks signal s -- the sigmask()
                                            ; convention, NOT the kernel's
                                            ; pending-bit layout).  Masked
                                            ; signals stay PENDING and deliver
                                            ; when unmasked.  Returns A=0.  The
                                            ; old mask is tracked by the libc
                                            ; shadow (single-threaded per task).
                                            ; tcsh's pfork blocks SIGCHLD around
                                            ; fork+palloc -- without a real mask
                                            ; the sequential snapshot-fork
                                            ; delivers SIGCHLD at the fork
                                            ; syscall's own exit, BEFORE the
                                            ; parent records the pid (2026-07-27).
SYS_SCREEN_CTL  EQU     101                 ; screen_ctl(A): 1=claim/suspend the
                                            ; console flush (userland owns SHR),
                                            ; 0=release+repaint.  Auto-released
                                            ; on task death (process.s).
SYS_FTRUNCATE   EQU     103                 ; ftruncate(fd, length): A=fd,
                                            ; X=length bits 0..15, Y=bits 16..23
SYS_UMASK       EQU     104                 ; umask(mask): A = new mask -> A = the
                                            ; PREVIOUS mask.  BSD's number for this
                                            ; is 60, which SYS_DMESG already holds,
                                            ; so it lands FGX-local -- the same
                                            ; situation this file records for setgid.
                                            ; Masked to 07777 as 2.11BSD and Reno
                                            ; both do (ufs_syscalls2.c:205,
                                            ; vfs_syscalls.c:1635).
                                            ; (ProDOS EOF is 24-bit).  Sets the
                                            ; file's LENGTH: a shorter length
                                            ; hides the tail from read(2) and
                                            ; stat(2); a longer one extends the
                                            ; file sparsely, reading as zeros.
                                            ; The file offset is NOT moved
                                            ; (POSIX).  BLOCKS ARE NOT RECLAIMED
                                            ; -- see apple/fgx#68.  C=1 ok /
                                            ; C=0+A=EBADF/EISDIR/EINVAL.
SYS_GETRLIMIT   EQU     105                 ; getrlimit(res, *rlp): A=res, Y=rlp
                                            ; offset, DBR=rlp bank -> A=0 / errno
SYS_SETRLIMIT   EQU     106                 ; setrlimit(res, *rlp): same shape
; 2.11BSD PUTS THESE AT 144/145 (init_sysent.c:254) AND FGX DOES NOT, for a
; reason worth stating once: the dispatch table is DENSE, indexed straight by
; syscall number, so honouring 144 would add forty _Sys_Stub entries -- eighty
; bytes of the scarcest bank -- to reach two useful ones.  The convention this
; file already follows is BSD's number where it is free and cheap, FGX-local
; otherwise; umask took the same route when SYS_DMESG held 60.
; sigsuspend(2)/sigpause(3).  A SYSCALL rather than libc's old mask-swap around
; a yield, because the two halves must be ATOMIC: installing the mask and going
; to sleep in separate syscalls leaves a window in which the awaited signal
; arrives, is handled, and the sleep then waits for one that has already been
; and gone.  2.11BSD's sigsuspend does both inside the kernel for the same
; reason, and returns EINTR unconditionally -- never ERESTART -- which this
; matches (kern_sig2.c says so in as many words).
SYS_SIGPAUSE    EQU     107                 ; sigpause(mask): A=lo16, X=hi16.
                                            ;   Installs the mask, sleeps until
                                            ;   a signal is actionable, and
                                            ;   always returns C=0 + A=EINTR.
SYS_GETPEERNAME EQU     108                 ; getpeername(fd, sockaddr_in*): X=fd,
                                            ;   A=sockaddr offset (caller bank).
                                            ;   Writes a full SIN_SIZE record --
                                            ;   the 3-arg BSD form's namelen is
                                            ;   libc's business, not the kernel's,
                                            ;   which keeps this to the two
                                            ;   registers SYS_CONNECT already uses.
                                            ;   C=0+A=ENOTCONN unless ESTABLISHED.
SYS_GETSOCKNAME EQU     109                 ; getsockname(fd, sockaddr_in*): same
                                            ;   shape.  An UNBOUND socket answers
                                            ;   0.0.0.0:0 with C=1, as BSD does --
                                            ;   "no name yet" is not an error.
SYS_MODLOAD     EQU     110                 ; FGX-specific: stream a module into
SYS_LSTAT       EQU     111                 ; lstat(path,buf): A=path X=stat_buf(own-bank) -> C=1 ok; C=0+A=errno.
                                            ;   stat(2) that does not FOLLOW a final symlink -- the only difference,
                                            ;   as 4.3BSD-Reno's own lstat is stat's six lines with NOFOLLOW.
SYS_READLINK    EQU     112                 ; readlink(path,buf,sz): A=path X=buf(own-bank) Y=size
SYS_SYMLINK     EQU     113                 ; symlink(target,linkname): A=target X=linkname
SYS_MOUNT       EQU     21                  ; mount(type,dir,flags,data): A = caller-bank
                                            ;   offset of libc's 4-word argument block,
                                            ;   dir and data in the same bank.  2.11BSD's
                                            ;   number (init_sysent.c:131), 4.3BSD-Reno's
                                            ;   arguments -- see _Sys_Mount
SYS_UMOUNT      EQU     22                  ; umount(spec): A=spec.  THE DEVICE, not the
                                            ;   directory -- 2.11BSD's interface, and what
                                            ;   umount(8) passes after normalising with
                                            ;   getmntinfo(3)
SYS_LDCTL       EQU     8                   ; ldctl(service, block): the shared-library registry (ld.mod): A=service X/Y=the 50-byte block (<sys/ldctl.h>) offset/bank; ENOSYS until ld.mod loads
SYS_LINK        EQU     9                   ; link(target,linkname): A=target X=linkname,
                                            ;   both in the caller's bank.  2.11BSD's own
                                            ;   number (init_sysent.c:119), a stub until now
; access(path, mode): A=path X=mode -> 0, or errno.  UFS 2.6.
; 33 IS 2.11BSD'S OWN NUMBER for access -- usr/sys/sys/init_sysent.c:143,
; "33 = access" -- which is this file's convention where the slot is free, and
; it was.
SYS_ACCESS      EQU     33
SYS_CHMOD       EQU     15                  ; chmod(path,mode): A=path X=mode.  2.11BSD's
                                            ;   own number (init_sysent.c:125), which the
                                            ;   table had kept as a stub
SYS_CHOWN       EQU     16                  ; chown(path,uid,gid): A=path X=uid Y=gid.
                                            ;   THREE arguments, as 2.11BSD's own comment
                                            ;   says: "16 = chown; now 3 args"
SYS_STATFS      EQU     114                 ; statfs(path,buf): A=path X=buf(own-bank)
                                        ;   (both own-bank) -> C=1 ok; C=0+A=errno.
                                        ;   The TARGET is contents, not a path to
                                        ;   resolve -- see root_symlink.
                                            ;   -> C=1 + A=byte count; C=0 + A=errno (EINVAL if not a symlink)
                                            ; a bank from userland.  A = subcmd
                                            ; (0 begin, 1 data, 2 end), X/Y per
                                            ; subcmd.  ONE syscall with a
                                            ; subcommand rather than three:
                                            ; each far-bank handler costs an
                                            ; 8-byte core stub plus a 2-byte
                                            ; dispatch entry, and the core bank
                                            ; has 43 bytes free.  SYS_MEMINFO
                                            ; (61) is the precedent.
                                            ; Plan: docs/history/plans/
                                            ; 2026-09-01-userland-modload.md B1.

SYS_FCHDIR      EQU     115                 ; fchdir(fd): A=fd.  UFS 2.7 --
                                            ; chmod(1)/chown(8) -R save the
                                            ; starting directory with
                                            ; open(".") and return to it
                                            ; with this.
SYS_REBOOT      EQU     116                 ; reboot(howto): A=howto (RB_*, see
                                            ; sys/reboot.h).  DOES NOT RETURN on
                                            ; success -- the machine halts or
                                            ; cold-starts.  C=0+A=errno only for
                                            ; a refusal before that point.
                                            ; 2.11BSD puts it at 55
                                            ; (init_sysent.c:165) and that number
                                            ; is squatted by SYS_BORDER, so this
                                            ; is FGX-local -- the same call
                                            ; SYS_VFORK made when SYS_POLLKEY
                                            ; held BSD's 66.
SYS_SYSCTL      EQU     117                 ; sysctl(name,namelen,old,oldlenp,
                                            ; new,newlen): A = caller-bank
                                            ; offset of libc's argument block,
                                            ; because six arguments do not fit
                                            ; three registers -- select(2) at 99
                                            ; is marshalled the same way.  It
                                            ; serves kern.securelevel,
                                            ; kern.clockrate, kern.boottime,
                                            ; the machdep node and the vm node
                                            ; (sysctl(3)); every other name is
                                            ; ENOTSUP.  The block is twelve
                                            ; words (far/root_sysctl.c): a value
                                            ; of up to 8 bytes travels in it,
                                            ; a larger one the kernel copies to
                                            ; oldp, words 10 and 11.
                                            ; 2.11BSD puts __sysctl at 202
                                            ; (init_sysent.c), above everything
                                            ; this table numbers, so this is
                                            ; FGX-local.
SYS_GETLOGIN    EQU     118                 ; getlogin(buf, len): A = caller-bank
                                            ; offset, X = size.  Copies the
                                            ; u-area's login name out; C=1 +
                                            ; A = bytes placed (0 = none set).
SYS_SETLOGIN    EQU     119                 ; setlogin(name): A = caller-bank
                                            ; offset of a NUL-terminated name.
                                            ; SUPER-USER ONLY, which is
                                            ; 2.11BSD's own rule for a kernel
                                            ; with no sessions
                                            ; (usr/sys/sys/kern_prot.c:186).
; BSD PUTS THESE AT 49 AND 50 (4.3BSD-Reno kern/syscalls.master:81-82) and both
; are already spent here on SYS_LISTDIR and SYS_GETKEY, so they land FGX-local
; above the table -- the same thing that happened to setgid, whose BSD number
; 46 was taken by SYS_VFORK.  2.11BSD renumbers them itself (getlogin at 39,
; setlogin at 43, init_sysent.c), so there is no single upstream number to
; match even in principle.
SYS_SIGPROCMASK EQU     120                 ; sigprocmask(how, set, oset):
                                            ; A = new mask lo16, X = hi16,
                                            ; Y = how.  C=1 + A = OLD mask
                                            ; lo16, Y = hi16 (the __syscall_y
                                            ; return-hi convention, as lseek
                                            ; uses); C=0 + A = EINVAL
                                            ; for an unknown how.  Same routine
                                            ; as SYS_SIGSETMASK, whose callers
                                            ; already pass how = 0
                                            ; (= SIG_SETMASK).  This 2.11BSD
                                            ; carries sigprocmask as syscall 32
                                            ; and marks 109/110 "(old
                                            ; sigblock)" / "(old sigsetmask)"
                                            ; (usr/sys/sys/syscalls.c).

; THE `how' CODES, and SIG_SETMASK is 0 so that SYS_SIGSETMASK's existing
; callers keep working unchanged -- libc's sigsetmask sends 0 as its third
; syscall argument.  Mirrored in toolchain/include/signal.h.
SIG_SETMASK     EQU     0                   ; replace the mask
SIG_BLOCK       EQU     1                   ; old | new
SIG_UNBLOCK     EQU     2                   ; old & ~new
SIG_QUERY       EQU     3                   ; read it back, change nothing
SIG_HOW_COUNT   EQU     4                   ; range check; above this = EINVAL

; `sigcantmask' -- the signals no task may block, in the USER bit convention
; (bit s-1) that SIGHND_MASK_OFF uses.  SIGKILL is 9, so $0100 of the low word;
; SIGSTOP is 17, so bit 0 of the high word.  vendor/2.11BSD/usr/sys/h/
; signalvar.h:121 defines it as `sigmask(SIGKILL) | sigmask(SIGSTOP)'.
SIG_CANTMASK_LO EQU     $0100               ; sigmask(SIGKILL)
SIG_CANTMASK_HI EQU     $0001               ; sigmask(SIGSTOP) >> 16

SYS_SETITIMER   EQU     121                 ; setitimer(which, itv, oitv):
                                            ; A = it_value SECONDS, X =
                                            ; it_interval SECONDS, Y = which.
                                            ; C=1 + A = the OLD counter's
                                            ; remaining TICKS lo16, Y = hi16
                                            ; (the __syscall_y return-hi
                                            ; convention); C=0 + A = EINVAL for
                                            ; any `which' but ITIMER_REAL, or
                                            ; ESRCH with no current task.
                                            ; SECONDS IN, TICKS OUT is not a
                                            ; muddle: upstream's ITIMER_REAL is
                                            ; whole seconds in and libc divides
                                            ; the remainder, which is the only
                                            ; value the kernel holds at tick
                                            ; resolution.  2.11BSD stores
                                            ; `it_value = aitv.it_value.tv_sec'
                                            ; and merely increments it when any
                                            ; tv_usec is set
                                            ; (usr/sys/sys/kern_time.c:215-223).

; `which' -- only ITIMER_REAL is implemented; the other two are EINVAL, which is
; a divergence to state rather than to discover.  Upstream keeps VIRTUAL and PROF
; in `u.u_timer[]' and charges them against CPU time, which FGX does not account.
ITIMER_REAL     EQU     0                   ; the wall-clock timer -> SIGALRM
ITIMER_VIRTUAL  EQU     1                   ; EINVAL here
ITIMER_PROF     EQU     2                   ; EINVAL here

; THE INTERVAL'S CEILING, and it is arithmetic rather than policy.  The reload
; table holds 16-bit TICKS (two bytes per task, against the counter's four), and
; seconds are converted the way `_Sys_Alarm' converts them, as s*64 - s*4 -- so
; the INTERMEDIATE s*64 is what binds, not the product: 1023*64 = 65472 fits and
; 1024*64 does not.  1023 s is 17m03s, against syslogd's 120 s mark interval.
; An interval above it is REFUSED with EINVAL and never truncated: a timer that
; silently fired at 44 seconds when asked for 300 is the shape apple/fgx#301 had.
; it_value has no such bound -- it lands in the 32-bit counter.
ITIMER_MAX_INTERVAL EQU 1023                ; seconds; s*64 must fit 16 bits

SYS_READV       EQU     122                 ; readv(fd, iov, iovcnt): A = fd,
                                            ; X = the iovec array (caller's
                                            ; DBR bank), Y = iovcnt.  C=1 +
                                            ; A = bytes read; C=0 + A = EBADF,
                                            ; or EINVAL for iovcnt > 16 or a
                                            ; total over 32767.  2.11BSD's is
                                            ; 120, spent here on sigprocmask.
SYS_WRITEV      EQU     123                 ; writev(fd, iov, iovcnt): as
                                            ; readv, writing.  One uio and one
                                            ; fo_write for the whole vector
                                            ; (2.11BSD sys_generic.c rwuio).
SYS_GETTIMEOFDAY EQU    124                 ; gettimeofday(blk): A = a 12-byte
                                            ; block (caller's DBR bank) that
                                            ; gets tv_sec, tv_usec,
                                            ; tz_minuteswest, tz_dsttime.  C=1
                                            ; + A = 0.  The kernel clock, UTC
                                            ; (tty/kern_time.c); 2.11BSD's is
                                            ; 116, FGX's SYS_REBOOT.
SYS_ADJTIME     EQU     125                 ; adjtime(blk): A = a 16-byte
                                            ; block (caller's DBR bank):
                                            ; delta's tv_sec and tv_usec in,
                                            ; olddelta's out.  Super user
                                            ; only.  C=1 + A = 0; C=0 + A =
                                            ; EPERM.  Slews the kernel clock
                                            ; (FreeBSD 2.2.8's rule).  FGX's
                                            ; number; 2.11BSD's is 140.
SYS_SETTIMEOFDAY EQU    126                 ; settimeofday(blk): A = a 14-byte
                                            ; block (caller's DBR bank): a
                                            ; flags word (bit 0 = tv given,
                                            ; bit 1 = tz given), tv_sec,
                                            ; tv_usec, tz_minuteswest,
                                            ; tz_dsttime.  Super user only.
                                            ; C=1 + A = 0; C=0 + A = EPERM.
                                            ; Sets the kernel clock and writes
                                            ; the battery clock back (FreeBSD
                                            ; resettodr).  2.11BSD's number.
SYS_FCNTL       EQU     127                 ; fcntl(fd, cmd, arg): A = fd,
                                            ; X = cmd, Y = arg.  C=1 + A =
                                            ; the value; C=0 + A = errno
                                            ; (EBADF, EINVAL, EMFILE).
                                            ; F_DUPFD, F_GETFD/F_SETFD (close
                                            ; on exec), F_GETFL/F_SETFL;
                                            ; F_GETOWN/F_SETOWN are EINVAL,
                                            ; FGX sending no SIGIO or SIGURG.
                                            ; 4.3BSD-Reno kern_descrip.c;
                                            ; 2.11BSD's number is 92.
SYS_FLOCK       EQU     128                 ; flock(fd, how): A = fd, X =
                                            ; LOCK_SH/LOCK_EX/LOCK_UN, with
                                            ; LOCK_NB.  C=1 + A = 0; C=0 + A
                                            ; = errno (EBADF, EOPNOTSUPP on
                                            ; a socket or pipe, EWOULDBLOCK,
                                            ; EINTR).  The lock is the
                                            ; vnode's; 4.3BSD-Reno
                                            ; kern_descrip.c and vfs_vnops.c.
                                            ; 2.11BSD's number is 131.
SYS_FCHOWN      EQU     129                 ; fchown(fd, uid, gid): A = fd,
                                            ; X = uid, Y = gid; -1 leaves an
                                            ; id alone.  C=1 + A = 0; C=0 +
                                            ; A = errno (EBADF, EINVAL on a
                                            ; socket or pipe, EROFS, EPERM).
                                            ; 4.3BSD-Reno vfs_syscalls.c.
                                            ; 2.11BSD's number is 123.
SYS_FCHMOD      EQU     130                 ; fchmod(fd, mode): A = fd, X =
                                            ; mode.  C=1 + A = 0; C=0 + A =
                                            ; errno (EBADF, EINVAL on a
                                            ; socket or pipe, EROFS, EPERM).
                                            ; 4.3BSD-Reno vfs_syscalls.c.
                                            ; 2.11BSD's number is 124.

SYS_NUM_MAX     EQU     SYS_FCHMOD          ; highest implemented (130)

; fcntl(2)'s commands (Reno sys/fcntl.h:26-40), the flags it touches -- FNDELAY
; (Reno's O_NONBLOCK, src/kernel/vfs/file.h), FCNTLCANT (Reno sys/file.h:70
; less the unix-domain gc marks FGX has no collector for: the access mode and
; the flock(2) lock bits) and
; UF_EXCLOSE (Reno sys/user.h:83) -- and the two close-on-exec ioctls
; (FreeBSD's _IO('f', 1) and _IO('f', 2) low 16, as toolchain/include/
; sys/ioctl.h has them).
F_SETFD         EQU     2
F_SETFL         EQU     4
FNDELAY         EQU     $0004
FCNTLCANT       EQU     $0183               ; FREAD|FWRITE|FSHLOCK|FEXLOCK
UF_EXCLOSE      EQU     $01
FIOCLEX         EQU     $6601
FIONCLEX        EQU     $6602
; UPDATE THIS WHEN YOU ADD A SYSCALL.  The dispatcher range-checks against it
; (syscall.s: `CMP #SYS_NUM_MAX+1`), so a number above it returns ENOSYS and the
; handler is never reached -- with the table entry sitting there looking wired.
; That failed silently once: umask landed at 104 with this still naming 103, and
; libc's umask, which has no failure return because BSD's cannot fail, handed
; ENOSYS (78) back to the caller AS THE PREVIOUS MASK.
; tools/gen_syscall_table.py now fails the build when this does not name the
; highest SYS_* number, because it used to report "in sync" throughout.

;------------------------------------------------------------------------------
; waitpid(2) option flags + wait-status decode (BSD <sys/wait.h> shape).
;------------------------------------------------------------------------------
WNOHANG         EQU     1                   ; don't block if no child is waitable
WUNTRACED       EQU     2                   ; also report stopped children

;------------------------------------------------------------------------------
; ioctl(2) command numbers (Phase 5.2 job control).  FGX passes the ioctl cmd
; in X (16-bit), so these are small FGX-local ids rather than BSD's 32-bit
; _IOR/_IOW-encoded values; the low bytes echo BSD <sys/ttycom.h> 't' group.
; arg points at a 16-bit pid/pgrp in the caller's data bank.
;------------------------------------------------------------------------------
TIOCGPGRP       EQU     $7477               ; get the tty's foreground pgrp -> *arg
TIOCSPGRP       EQU     $7476               ; set the tty's foreground pgrp <- *arg

;------------------------------------------------------------------------------
; sgtty(2) — old-style get/set terminal parameters (vi-port slice 4.3).  cmd
; high byte $74 = BSD 't' group, low byte = the BSD <sgtty.h> index.  arg points
; at a 10-byte `struct sgttyb` in the caller's data bank.  gtty(2)=TIOCGETP,
; stty(2)=TIOCSETP; TIOCSETN sets without flushing typeahead (we never flush, so
; it is identical here).  The sgttyb is 10 bytes (5 x 2-byte fields — fcc gives
; each struct member a 2-byte slot).  NO LONGER TRUE: fcc packs `char' at one
; byte since B-8, and T3 stage 2d took BSD's 6-byte `struct sgttyb'.
;------------------------------------------------------------------------------
TIOCGETP        EQU     $7408               ; gtty: *arg = tty sgttyb
TIOCSETP        EQU     $7409               ; stty: tty sgttyb = *arg (flush)
TIOCSETN        EQU     $740A               ; stty: as TIOCSETP, no flush

; A CD-ROM's eject: netbsd-0-9's CDIOCEJECT, _IO('c', 24) (sys/sys/cdio.h:144),
; less the size bits FGX's 16-bit ioctl numbers do not carry.
CDIOCEJECT      EQU     $6318

;------------------------------------------------------------------------------
; pty ioctls (pty subsystem plan 2026-07-20).  Values mirror toolchain
; include/sgtty.h (the C side) — keep in sync.  TIOCGLTC/TIOCSLTC are
; store/return only (no behavior; telnet-family mode() must succeed).
;------------------------------------------------------------------------------
TIOCFLUSH       EQU     $7410               ; flush tty input/output queues
TIOCNOTTY       EQU     $7471               ; give up the controlling terminal:
                                            ; ctty = none AND pgrp = 0.  2.11BSD
                                            ; _IO(t,113) (sys/h/ioctl.h:200);
                                            ; handled in tty_tty.c:57-62 as pure
                                            ; process state, which is why FGX can
                                            ; accept it on ANY tty fd without a
                                            ; /dev/tty node.  The primitive a
                                            ; session-creating daemon calls before
                                            ; opening the line it means to own --
                                            ; see telnetd.c:266-271.
TIOCPKT         EQU     $7470               ; pty master: packet mode on/off
; The status bits `pt_send' carries, `usr/sys/h/ioctl.h:202-208'.  One of them
; heads the master's read whenever `pt_send' is non-zero, ahead of any data.
; FLUSHREAD and FLUSHWRITE SHARE THEIR VALUES WITH FREAD AND FWRITE, and that
; is not a coincidence: `ptsstop' is handed the flush mask and ORs it straight
; into `pt_send' -- upstream's comment there is "note: FLUSHREAD and FLUSHWRITE
; already ok".
TIOCPKT_DATA    EQU     $00                 ;   normal data
TIOCPKT_FLUSHREAD EQU  $01                  ;   input flushed
TIOCPKT_FLUSHWRITE EQU $02                  ;   output flushed
TIOCPKT_STOP    EQU     $04                 ;   output stopped
TIOCPKT_START   EQU     $08                 ;   output restarted
TIOCPKT_NOSTOP  EQU     $10                 ;   no more ^S/^Q -- NOT ARMED HERE
TIOCPKT_DOSTOP  EQU     $20                 ;   now do ^S/^Q  -- NOT ARMED HERE
TIOCGLTC        EQU     $7474               ; get local special chars (ltchars)
TIOCSLTC        EQU     $7475               ; set local special chars (ltchars)
; BSD "local mode" word (tcsh Rawmode enablement 2026-07-27).  tcsh's editor
; HARD-REQUIRES TIOCLGET (and TIOCGLTC): a failure return makes Rawmode()
; return -1, which GetNextChar() turns into a fabricated EOF -> interactive
; tcsh prints "exit" and quits without ever issuing a read.
TIOCLGET        EQU     $747C               ; get local mode word -> *arg
TIOCLSET        EQU     $747D               ; set local mode word <- *arg
TIOCLBIS        EQU     $747F               ; OR *arg into the local mode word
TIOCLBIC        EQU     $747E               ; clear *arg bits from the word
TIOCISCONS      EQU     $7461               ; FGX: *arg = 1 iff fd is the PHYSICAL
                                            ; console (tty[0]), else 0.  Lets a
                                            ; shell pick the SYS_GETKEY console
                                            ; line editor vs plain fd-0 reads —
                                            ; jsh over a pty reads fd 0 (pty
                                            ; subsystem / telnetd enablement).
TIOCGWINSZ      EQU     $7468               ; *arg = struct winsize {row,col,
                                            ; xpix,ypix} (4 words; console is
                                            ; CON_VIS_ROWS x CON_VIS_COLS,
                                            ; pixels 0).  BSD 't'<<8|104.
TIOCSWINSZ      EQU     $7467               ; *arg -> this tty's winsize, and
                                            ; SIGWINCH its foreground group if
                                            ; the size CHANGED (2.11BSD
                                            ; tty.c:558).  BSD 't'<<8|103.
FIODGNAME       EQU     $6678               ; *arg = this tty's device name, NUL-
                                            ; terminated, at most TTYNAME_MAX
                                            ; bytes, no "/dev/" prefix (libc's
                                            ; ttyname() adds it).  'f' group like
                                            ; FIOCLEX/FIONBIO: FreeBSD's
                                            ; _IOW('f',120) low 16.  Mirrors
                                            ; FIODGNAME in toolchain
                                            ; include/sys/ioctl.h -- keep in sync.

;------------------------------------------------------------------------------
; tchars(2) — old-style get/set the tty's special characters (vi-port curses
; seam).  Same 't' group; low byte = the BSD <sgtty.h> index.  arg points at a
; `struct tchars` (intr/quit/start/stop/eof/brk) in the caller's data bank.  Like
; sgttyb, fcc gives each field a 2-byte slot, so the C struct is all-`short` and
; the kernel-side image is `ttys[].t_chars' in the TTY BANK since T3 stage 2b
; (include/ktty.s TTYC_CHARS), where ttioctl answers GETC/SETC.  Round-trip only:
; the chars are stored/returned so curses' save-set-restore works, but the line
; discipline does not yet act on them (^C -> SIGINT is a later signal-model step).
;------------------------------------------------------------------------------
TIOCSTI         EQU     $7472               ; simulate terminal input: push *arg
                                            ; back into the line as if typed.
                                            ; NOT ROUTED to the tty bank yet --
                                            ; ttioctl gates it on `flag & FREAD'
                                            ; and FGX's FCB records only a WRITE
                                            ; bit, so the descriptor mode it
                                            ; needs is not derivable.  See
                                            ; _Tty_Ioctl (ttyv.s).
TIOCGETC        EQU     $7412               ; get special chars: *arg = tty tchars
TIOCSETC        EQU     $7411               ; set special chars: tty tchars = *arg

;------------------------------------------------------------------------------
; struct sgttyb sg_flags bits (2.11BSD <sgtty.h> values).  Only the subset the
; console line discipline + vi use is acted on; the rest round-trip via gtty/
; stty but are inert until a driver (e.g. serial) honors them.
;------------------------------------------------------------------------------
SG_TANDEM       EQU     $0001               ; flow control (inert on console)
SG_CBREAK       EQU     $0002               ; char-at-a-time, signals active
SG_ECHO         EQU     $0008               ; echo input
SG_CRMOD        EQU     $0010               ; cooked tty ONLCR: LF->CR+LF on output (ttyv write); ICRNL on input
SG_RAW          EQU     $0020               ; char-at-a-time, no processing
SG_XTABS        EQU     $0400               ; expand tabs on output (inert)
SG_RAWCB        EQU     SG_RAW+SG_CBREAK    ; mask: either => char-at-a-time read

; Local-mode word L* bits (toolchain include/sgtty.h values — keep in sync).
; Only the boot-default trio is named here; the word itself round-trips via
; TIOCLGET/LSET/LBIS/LBIC and the discipline does not branch on it yet.
L_CRTBS         EQU     $0001               ; backspacing for crt
L_CRTERA        EQU     $0004               ; "\b \b" erase
L_CRTKIL        EQU     $0400               ; kill line with "\b \b"

;------------------------------------------------------------------------------
; Signal numbers.  Stubs only in slice-2; real delivery (keyboard SIGINT,
; SIGCHLD on _exit, etc.) lands once we have either preemption or a kernel-
; resident polling check.  Numbers follow 2.11BSD <sys/signal.h>.
;------------------------------------------------------------------------------
; Full BSD set (2.11BSD <sys/signal.h>).  Default actions + uncatchable
; enforcement land in signal.s (Phase 5.1); many are accept-but-inert until a
; source posts them.
SIGHUP          EQU     1                   ; hangup
SIGINT          EQU     2                   ; Ctrl-C (interactive interrupt)
SIGQUIT         EQU     3                   ; quit (Ctrl-\)
SIGILL          EQU     4                   ; illegal instruction
SIGTRAP         EQU     5                   ; trace trap
SIGABRT         EQU     6                   ; abort()
SIGEMT          EQU     7                   ; emulator trap
SIGFPE          EQU     8                   ; arithmetic exception
SIGKILL         EQU     9                   ; uncatchable terminate
SIGBUS          EQU     10                  ; bus error
SIGSEGV         EQU     11                  ; segmentation violation
SIGSYS          EQU     12                  ; bad argument to syscall
SIGPIPE         EQU     13                  ; write to closed pipe
SIGALRM         EQU     14                  ; alarm timer expired (vi-port slice 3)
SIGTERM         EQU     15                  ; software termination
SIGURG          EQU     16                  ; urgent condition on socket
SIGSTOP         EQU     17                  ; uncatchable stop
SIGTSTP         EQU     18                  ; keyboard stop (Ctrl-Z)
SIGCONT         EQU     19                  ; continue if stopped
SIGCHLD         EQU     20                  ; child stopped/exited
SIGTTIN         EQU     21                  ; background read from tty
SIGTTOU         EQU     22                  ; background write to tty
SIGIO           EQU     23                  ; I/O possible
SIGXCPU         EQU     24                  ; CPU time limit exceeded
SIGXFSZ         EQU     25                  ; file size limit exceeded
SIGVTALRM       EQU     26                  ; virtual time alarm
SIGPROF         EQU     27                  ; profiling timer alarm
SIGWINCH        EQU     28                  ; window size change
SIGINFO         EQU     29                  ; information request
SIGUSR1         EQU     30                  ; user-defined signal 1
SIGUSR2         EQU     31                  ; user-defined signal 2
NSIG            EQU     32                  ; signal numbers are 1..NSIG-1

SIG_DFL         EQU     0                   ; default handler (in v1: same as IGN)
SIG_IGN         EQU     1                   ; ignore

;------------------------------------------------------------------------------
; User-space layout.  See spec §3.2 bank table.
;------------------------------------------------------------------------------
FGX_USER_BASE   EQU     $0A0000             ; first user bank (init's bank)
FGX_USER_BANK   EQU     $0A                 ; bank byte (= FGX_USER_BASE >> 16)
HELLO_LOAD_ADDR EQU     $0A0000             ; slice 1: hello loads at the user base

;------------------------------------------------------------------------------
; User-bank pool.  BANK_USER_COUNT is the pool's capacity; the live pool is
; what the loader claimed (Bank_Init reads KFGX_REST_COUNT), so a small-RAM
; machine is unaffected.  src/kernel/bank.s keeps it as a page map.
;------------------------------------------------------------------------------
BANK_USER_COUNT EQU     CFG_REST_USER_BANKS ; rest.user_banks (cfg/system.cfg):
                                            ;   56, because the pool ran dry at
                                            ;   24 with two virtual consoles
                                            ;   live (apple/fgx#37, #41)
BANK_USER_FIRST EQU     $0A                 ; lowest user bank at the static
                                            ;   $02 build
BANK_USER_LAST  EQU     BANK_USER_FIRST+BANK_USER_COUNT-1

;------------------------------------------------------------------------------
; Loader return convention (Load_Binary):
;   On success: C=1, _ldEntry = entry address (24-bit), _ldUserBank = load bank.
;   On failure: C=0, A = errno (8-bit).
;------------------------------------------------------------------------------

;==============================================================================
; Slice-3 stack-laid argv/envp frame.
;
; At first-run entry, the child's stack page (in bank 0 at TCB_StackBase, carved
; from FGX_STK_ARENA by Task_AllocStack) holds the BSD-shaped argv/envp frame.
; This used to read "FGX_STK_TASKS + (pid << 8)", describing the pre-2026-07-27
; fixed pid-indexed scheme that no longer exists -- _Loader_StageArgs works from
; TCB_StackBase..+TCB_StackSize.  The stale wording implied live data at $3000+
; and nearly blocked the B1b arena reclaim (2026-07-31).  After
; the dispatcher's PLB+RTL pops the 4-byte resume frame, S points at the
; byte just below `argc`, so user `_start` can read everything via
; stack-relative addressing under M=00:
;
;   LDA  LSARGV_ARGC,S       ; 16-bit argc
;   LDA  LSARGV_ARGV0,S      ; 16-bit ptr to argv[0]   (bank-0 address)
;   LDA  LSARGV_ARGV0+2,S    ; 16-bit ptr to argv[1]
;   ...
;   LDA  LSARGV_ARGV0+2*argc,S = NULL (argv terminator)
;   then envp[] (NULL-term) starts immediately after.
;
; Pointers in argv[]/envp[] are 16-bit bank-0 offsets (the strings live
; on this same stack page, copied there by the kernel from caller-bank
; NUL-terminated source strings).  To dereference a string, build a
; long pointer with bank=0 and use [dp]:
;
;   REP   #$30
;   LDA   LSARGV_ARGV0,S     ; argv[0] addr
;   STA   <dp_lo>            ; lo word of long ptr
;   STZ   <dp_hi>            ; bank = 0 (1 byte; rest of word ignored)
;   LDA   [<dp_lo>]          ; first byte of argv[0] string
;
; Total frame size budget: 256 bytes minus the runtime stack the child
; needs at startup.  In practice ~200 B of usable strings/ptrs.  The
; kernel rejects layouts that exceed STK_PAGE - resume_frame_size as
; E2BIG (errno 7).
;------------------------------------------------------------------------------
LSARGV_ARGC     EQU     1                   ; offset from S to argc word
LSARGV_ARGV0    EQU     3                   ; offset from S to argv[0] ptr
                                            ; (argv ptrs follow contiguously;
                                            ;  argv[i] at LSARGV_ARGV0 + 2*i;
                                            ;  argv[argc] = NULL terminator;
                                            ;  envp[0] starts right after)

;==============================================================================
; Layout produced by the kernel side (_Loader_StageArgs).  Walking BOTTOM-UP
; from the saved S (= byte BELOW the resume frame's lowest byte = DBR):
;
;   saved_S+1   DBR  (= child bank — pulled by PLB)
;   saved_S+2   PCL  (low byte of entry-1 — first byte pulled by RTL)
;   saved_S+3   PCH  (high byte of entry-1)
;   saved_S+4   PB   (= child bank — last byte pulled by RTL)
;   saved_S+5   argc lo                        \_  reachable as 1,S
;   saved_S+6   argc hi                        /
;   saved_S+7   argv[0] lo                     \_  reachable as 3,S
;   saved_S+8   argv[0] hi                     /
;   ...
;   saved_S+5+2*argc      NULL lo (argv term)
;   saved_S+6+2*argc      NULL hi
;   saved_S+7+2*argc      envp[0] lo
;   ...
;   <strings region — argv strings followed by envp strings, NUL-terminated>
;   stack_top  (last byte of stack page, e.g. $0032FF for PID 2)
;
; After the dispatcher's PLB+RTL, S = saved_S + 4, which is the byte
; immediately below argc.  `LDA LSARGV_ARGC,S` reads argc.
;==============================================================================
