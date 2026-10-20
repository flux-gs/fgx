;==============================================================================
; fs.s - FGX filesystem module (read-only ProDOS).
;
; See docs/superpowers/specs/2026-04-19-fgx-filesystem-design.md for design.
;==============================================================================

                MX      %00

;------------------------------------------------------------------------------
; Fs_Init - zero the fs buffers in the kernel data region.
;------------------------------------------------------------------------------
Fs_Init         MX      %00
                PHP
                REP     #$30
                MX      %00

                ; Zero each fs buffer individually — canaries are
                ; interleaved between buffers (see include/memmap.s)
                ; and must not be overwritten.  The _ZeroBankRegion
                ; macro zeros [start, end), so passing the next canary
                ; label as `end` stops exactly at the canary byte.
                _ZeroBankRegion _fsDirBuf;KMem_fsDirBuf_canary
                _ZeroBankRegion _fsStatBuf;KMem_fsStatBuf_canary
                _ZeroBankRegion _fsLastDirInfo;KMem_fsLastDirInfo_canary
                ; (_fsCwd retired -> per-task heap cwd table; nothing to zero here.
                ; KMem_fsCwd_canary remains as a guard byte, sentinel-set in main.s.)
                _ZeroBankRegion _blkSrcPool;KMem_fw_canary
                _ZeroBankRegion _frnDstBank;KMem_frn_canary
                PLP
                RTS

;==============================================================================
; Fs_Stat - stat a path: resolve, walk, populate _fsStatBuf.
;
; Input:  X = bank-$02 ptr to null-terminated path string.
; Output: C=1 + X = #_fsStatBuf (11-byte struct stat in bank $02).
;         C=0 + A = errno (ENOENT, ENOTDIR, ENAMETOOLONG, EINVAL, EIO).
;
; _fsStatBuf layout (see include/fs.s):
;   $00  ST_Mode        : $80=dir, $40=file, $20=other
;   $01  ST_Size+0..+2  : 3-byte EOF
;   $04  ST_Blocks+0..+1: 2-byte blocks used
;   $06  ST_KeyBlock+0..+1: 2-byte key block pointer
;   $08  ST_ProFlags    : access byte
;   $09  ST_ProStorage  : raw storage nibble ($10/$20/etc.)
;   $0A  (padding = 0)
;
; _fsStatBuf field addresses (label-relative; EQU+offset is fine as the
; base of LDAL/STAL — resolves to an absolute address at assembly time).
;==============================================================================

; THE BSD FIELDS, at include/fs.s's STX_ offsets.  Spelled as EQUs here for
; the same reason they always were: `EQU + offset' resolves at assembly time
; and is legal as the base of an LDAL/STAL.
_fsStat_Dev     EQU     _fsStatBuf+0        ; STX_dev     (word)
_fsStat_Ino     EQU     _fsStatBuf+2        ; STX_ino     (word)
_fsStat_Mode    EQU     _fsStatBuf+4        ; STX_mode    (word, S_IF* | perm)
_fsStat_Nlink   EQU     _fsStatBuf+6        ; STX_nlink   (word)
_fsStat_Uid     EQU     _fsStatBuf+8        ; STX_uid     (word)
_fsStat_Gid     EQU     _fsStatBuf+10       ; STX_gid     (word)
_fsStat_Rdev    EQU     _fsStatBuf+12       ; STX_rdev    (word)
_fsStat_SizLo   EQU     _fsStatBuf+14       ; STX_size    (4 B; byte 3 always 0)
_fsStat_SizMd   EQU     _fsStatBuf+15
_fsStat_SizHi   EQU     _fsStatBuf+16
_fsStat_Atime   EQU     _fsStatBuf+18       ; STX_atime   (4 B)
_fsStat_Mtime   EQU     _fsStatBuf+24       ; STX_mtime   (4 B)
_fsStat_Ctime   EQU     _fsStatBuf+30       ; STX_ctime   (4 B)
_fsStat_BlkSize EQU     _fsStatBuf+36       ; STX_blksize (4 B)
_fsStat_BlkLo   EQU     _fsStatBuf+40       ; STX_blocks  (4 B)
_fsStat_BlkHi   EQU     _fsStatBuf+41
_fsStat_Flags   EQU     _fsStatBuf+44       ; STX_flags   (word)

; The two fields below are not part of the legacy ST_* layout — they're
; populated from _Fs_WalkPath's last Blk_Read so Fs_Open can wire the
; write-path _fw* state without re-walking the path.  Zero on virtual-root
; stat (no real ProDOS entry).
; Kernel-internal channel between Fs_Stat and Fs_Open: dir block
; holding the matched entry + entry's byte offset within that block.
; Moved out of _fsStatBuf (where these used to squat at +11..+14) so
; userland can see mtime at those offsets via SYS_STAT.
_fsStat_DirBlk  EQU     _fsLastDirInfo+0    ; 2 B
_fsStat_DEOff   EQU     _fsLastDirInfo+2    ; 2 B

; Mtime fields (newly exposed to userland). Match ST_ModDate / ST_ModTime
; offsets in the ST_* struct declared in include/fs.s.
; THE RAW ProDOS DATE AND TIME WORDS HAVE NO HOME HERE ANY MORE.  They were
; carried out to userland verbatim and unpacked by libc; a BSD struct has a
; Unix epoch instead, and the only producer that knows one is root_stat, from
; the vattr.  The legacy arm leaves the three times ZERO, which is the honest
; answer for a path that no longer has a filesystem under it -- see the note
; at @fs_legacyTimes.

;------------------------------------------------------------------------------
; _Fs_RootStat - stat a path against the mounted root, if there is one.  The
; name may be RELATIVE: it is resolved from the caller's cwd vnode, which is
; what `vfs_cdir' is for and what apple/fgx#295 was.  The first of the nine Path_Resolve entry points to be answered by
; namei; `_Fs_RootOpen' above is its sibling and the argument for the shape is
; written there.
;
; A MISS FALLS THROUGH AND DOES NOT FAIL, so a machine with no root mounted
; reaches the legacy resolver exactly as before and this can only add a
; capability.  root_stat answers ENXIO when root_status is not 1.
;
; NO pid AND NO DESCRIPTOR.  A stat opens nothing, so there is no _Fcb_Alloc to
; pair with and no _Fcb_OwnerPid to ask -- which is what makes this the cheapest
; of the nine and the right one to convert first.
;
; In:  X = path offset in THIS bank.  MX %00.
; Out: C=1 + X = #_fsStatBuf, filled.  C=0 and the caller carries on.
;------------------------------------------------------------------------------
_Fs_RootStat    MX      %00
                PHP
                REP     #$30
                MX      %00
                ; RELATIVE NAMES TOO, SINCE THERE IS A DIRECTORY TO ASK.  An
                ; absolute-only test stood here, on root_open's old reasoning:
                ; "root_stat walks from the system root, so a relative path
                ; would be resolved against a directory this call never chose."
                ; The premise stopped being true when the cwd became a vnode --
                ; root_stat chooses the CALLER's directory now, the same one
                ; root_open does -- and the test then cost more than a miss:
                ; `.' fell through to the legacy resolver, which on a 2.11BSD
                ; volume says "not found", so a bare `ls' failed while `ls /etc'
                ; worked (apple/fgx#295).  stat gates every directory operation,
                ; which is why that one test reached so far.
                PHX                             ; the path, across the pushes
                ; root_stat(name, sb), fcc right to left: sb goes down first.
                ; Both pointers are FOUR bytes -- pad, bank, offset -- and both
                ; banks are THIS one, pushed with PHK rather than a `^' literal
                ; so relocation cannot bake the assembly bank.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; sb: pad
                PHK                             ;     bank
                REP     #$30
                MX      %00
                LDA     #_fsStatBuf
                PHA                             ;     offset
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; name: pad
                PHK                             ;       bank
                REP     #$30
                MX      %00
                LDA     7,S                     ;       offset (the saved path)
                PHA
                ; AND THE pid LAST, BEING THE FIRST ARGUMENT: fcc reads right to
                ; left.  `_Fcb_OwnerPid' and not `_curTask' for the reason
                ; fcb.s gives and Fs_Chdir already follows -- a service running
                ; inside spawn is about the CHILD.
                JSR     _Fcb_OwnerPid
                PHA
_kfp907         JSL     KFAR_VFS_ROOTSTAT       ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #10                     ; drop the copy -- caller cleans
                TCS
                ; THE POP COMES FIRST, AND THAT ORDER IS THE WHOLE ARM.
                ; PLX sets N and Z from the value PULLED, so a `TYA / PLX /
                ; BNE' tests the saved PATH POINTER and not the errno -- and a
                ; path offset is never zero, so the success arm was
                ; unreachable and every root stat took the miss.  root_stat
                ; was answering correctly the whole time (measured: it
                ; resolves /etc, and reports mode $80).  Popping first leaves
                ; TYA's flags the ones the branch reads.
                PLX                             ; drop the saved path
                TYA
                BNE     @frs_no
                LDX     #_fsStatBuf             ; the contract: X names the buf
                PLP
                SEC
                RTS
@frs_no         PLP
                CLC
                RTS

;------------------------------------------------------------------------------
; _Fs_RootFstat - fstat an OPEN FD through the mounted root.  apple/fgx#365.
;
; `_Fs_RootStat' reaches a vnode by NAME; this reaches one by DESCRIPTOR, and
; both convert it through the one `vn_stat'.  That is Reno's arrangement --
; stat(2) in kern/vfs_syscalls.c and fstat(2) in kern/kern_descrip.c calling one
; kern/vfs_vnops.c function -- and the reason it matters here is that the two
; had DIFFERENT answers while fstat read the FCB: st_ino came back 0, because an
; FCB cannot know an inode, and `getwd(3)' decides it has reached the root by
; comparing stat's inode against fstat's.  It never matched, so the walk never
; terminated and ran off its 128-byte buffer.
;
; THE pid COMES FROM `_Fcb_OwnerPid' AND NOT `_curTask', for the reason fcb.s
; gives and `_Fs_RootStat' already follows: a service running inside spawn is
; about the CHILD.
;
; In:  A = fd.  MX %00.
; Out: C=1 + X = #_fsStatBuf, filled.  C=0 and the caller carries on.
;------------------------------------------------------------------------------
_Fs_RootFstat   MX      %00
                PHP
                REP     #$30
                MX      %00
                PHA                             ; the fd, across the pushes
                ; root_fstat(pid, fd, sb), fcc right to left: sb goes down
                ; first.  It is FOUR bytes -- pad, bank, offset -- and the bank
                ; is THIS one, pushed with PHK rather than a `^' literal so
                ; relocation cannot bake the assembly bank.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; sb: pad
                PHK                             ;     bank
                REP     #$30
                MX      %00
                LDA     #_fsStatBuf
                PHA                             ;     offset
                LDA     5,S                     ; fd (the saved one)
                PHA
                JSR     _Fcb_OwnerPid
                PHA
_kfp992         JSL     KFAR_VFS_ROOTFSTAT      ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #8                      ; drop the copy -- caller cleans
                TCS
                ; THE POP COMES FIRST, for the reason `_Fs_RootStat' records:
                ; PLX sets N and Z from the value PULLED, so testing the errno
                ; after it would test the saved fd instead.
                PLX                             ; drop the saved fd
                TYA
                BNE     @frf_no
                LDX     #_fsStatBuf             ; the contract: X names the buf
                PLP
                SEC
                RTS
@frf_no         PLP
                CLC
                RTS

_Fs_RootLstat   MX      %00
                PHP
                REP     #$30
                MX      %00
                ; lstat(2)'s stub, and it is _Fs_RootStat's twin BYTE FOR BYTE
                ; except for the slot it calls: same ten argument bytes, same
                ; buffer, same miss contract.  The difference is entirely on
                ; the far side, where root_lstat asks namei without FOLLOW.
                ;
                ; A CLONE RATHER THAN A FLAG, for the seam's reason: carrying
                ; one would need an eleventh argument byte and would make both
                ; roads pay for it.
                ;
                ; RELATIVE NAMES TOO, SINCE THERE IS A DIRECTORY TO ASK.  An
                ; absolute-only test stood here, on root_open's old reasoning:
                ; "root_stat walks from the system root, so a relative path
                ; would be resolved against a directory this call never chose."
                ; The premise stopped being true when the cwd became a vnode --
                ; root_stat chooses the CALLER's directory now, the same one
                ; root_open does -- and the test then cost more than a miss:
                ; `.' fell through to the legacy resolver, which on a 2.11BSD
                ; volume says "not found", so a bare `ls' failed while `ls /etc'
                ; worked (apple/fgx#295).  stat gates every directory operation,
                ; which is why that one test reached so far.
                PHX                             ; the path, across the pushes
                ; root_stat(name, sb), fcc right to left: sb goes down first.
                ; Both pointers are FOUR bytes -- pad, bank, offset -- and both
                ; banks are THIS one, pushed with PHK rather than a `^' literal
                ; so relocation cannot bake the assembly bank.
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; sb: pad
                PHK                             ;     bank
                REP     #$30
                MX      %00
                LDA     #_fsStatBuf
                PHA                             ;     offset
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; name: pad
                PHK                             ;       bank
                REP     #$30
                MX      %00
                LDA     7,S                     ;       offset (the saved path)
                PHA
                ; AND THE pid LAST, BEING THE FIRST ARGUMENT: fcc reads right to
                ; left.  `_Fcb_OwnerPid' and not `_curTask' for the reason
                ; fcb.s gives and Fs_Chdir already follows -- a service running
                ; inside spawn is about the CHILD.
                JSR     _Fcb_OwnerPid
                PHA
_kfp974         JSL     KFAR_VFS_ROOTLSTAT      ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #10                     ; drop the copy -- caller cleans
                TCS
                ; THE POP COMES FIRST, AND THAT ORDER IS THE WHOLE ARM.
                ; PLX sets N and Z from the value PULLED, so a `TYA / PLX /
                ; BNE' tests the saved PATH POINTER and not the errno -- and a
                ; path offset is never zero, so the success arm was
                ; unreachable and every root stat took the miss.  root_stat
                ; was answering correctly the whole time (measured: it
                ; resolves /etc, and reports mode $80).  Popping first leaves
                ; TYA's flags the ones the branch reads.
                PLX                             ; drop the saved path
                TYA
                BNE     @frl_no
                LDX     #_fsStatBuf             ; the contract: X names the buf
                PLP
                SEC
                RTS
@frl_no         PLP
                CLC
                RTS


; Fs_Lstat -- lstat(2): Fs_Stat with the root arm asked not to FOLLOW.
;
; A FLAG AND NOT A SECOND COPY.  Everything Fs_Stat does before the root hook
; -- the path guards -- is identical for
; lstat, and everything after it (the legacy arm) has no symlinks to follow
; anyway.  Cloning the routine to change one JSR would cost the core bank a
; few hundred bytes it does not have.
;
; THE FLAG IS NOT LIVE ACROSS A SLEEP, which is what makes a singleton safe
; here: it is set at this entry, read once at the root hook a few instructions
; later, and the FS layer does not sleep -- tools/check_fs_sleep_invariant.py
; is what holds that, and it is the same property every other _fs* singleton
; in this file already depends on.
;==============================================================================
; Fs_Readlink - readlink(2) against the mounted root.
;
; In:  X = bank-$02 ptr to the path, Y = destination offset in bank $02,
;      A = buffer size.
; Out: C=1 + A = bytes placed; C=0 + A = errno.
;
; NO LEGACY ARM, unlike Fs_Stat.  Nothing the legacy resolver can reach is a
; symlink -- ProDOS has no symlinks at all -- so it would answer EINVAL, which
; is what a miss here already answers.  The root is the only place a symlink
; can exist.
;==============================================================================
Fs_Readlink     MX      %00
                PHP
                REP     #$30
                MX      %00
                PHA                             ; the size, across the pushes
                PHY                             ; the destination
                PHX                             ; the path
                ; root_readlink(pid, name, buf, count), fcc right to left:
                ; count first, then buf, then name, then pid.  Both pointers
                ; are four bytes -- pad, bank, offset -- and both banks are
                ; THIS one, pushed with PHK so relocation cannot bake the
                ; assembly bank.
                LDA     5,S                     ; count
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; buf: pad
                PHK                             ;      bank
                REP     #$30
                MX      %00
                ; SEVEN, NOT FIVE.  Above SP here: bank(1) pad(1) count(2)
                ; path(2) dest(2) size(2), so the destination is at 7.  Five
                ; reads the PATH, which pushed the name as the buffer and made
                ; every readlink fail -- visible as `ls -l' printing a symlink
                ; with no `-> target'.
                LDA     7,S                     ;      offset (saved dest)
                PHA
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; name: pad
                PHK                             ;       bank
                REP     #$30
                MX      %00
                ; NINE, by the same count: the four bytes of the buf pointer
                ; and this pointer's own pad and bank sit above the trio now.
                LDA     9,S                     ;       offset (saved path)
                PHA
                JSR     _Fcb_OwnerPid
                PHA
_kfp975         JSL     KFAR_VFS_ROOTREADLINK   ; bank byte patched by Far_Init
                TAY                             ; park the result; TSC needs A
                TSC
                CLC
                ADC     #12                     ; drop the copy -- caller cleans
                TCS
                PLX                             ; drop the saved path
                PLX                             ; ...the destination
                PLX                             ; ...and the size
                ; A COUNT OR A NEGATIVE ERRNO, which is upstream's convention
                ; (Reno returns `uap->count - auio.uio_resid').  A negative
                ; result is an errno with its sign flipped, so BMI picks the
                ; error arm and the negate makes it positive again.
                TYA
                BMI     @frd_err
                PLP
                SEC
                RTS
@frd_err        EOR     #$FFFF
                INC
                PLP
                CLC
                RTS

Fs_Lstat        MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDA     #$01
                STA    |_fsStatNoFollow
                REP     #$30
                MX      %00
                BRA     @fs_statGo

Fs_Stat         MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                STZ    |_fsStatNoFollow
                REP     #$30
                MX      %00
@fs_statGo

                ; THE PATH POINTER IS PUSHED FOR THE WALK BELOW, which reads
                ; it back off the stack -- Fs_Stat pops it, Fs_Open reads it at
                ; `1,S'.
                PHX                                 ; preserve raw path ptr
                SEP     #$20
                MX      %10
@fs_notDev      MX %10
                REP     #$30
                MX      %00
                PLX                                 ; restore raw path ptr

                ; --- THE ROOT, BEFORE THE LEGACY FST (the path conversion) ---
                ; EVERY PATH REACHING HERE IS AN ORDINARY ONE, device names
                ; included: a device is an inode on the root, so the root is
                ; the right authority for all of them.
                SEP     #$20
                MX      %10
                LDA    |_fsStatNoFollow
                REP     #$30
                MX      %00
                BNE     @fs_rootLstat
                JSR     _Fs_RootStat
                BRA     @fs_rootDone
@fs_rootLstat   JSR     _Fs_RootLstat
@fs_rootDone    BCC     @fs_rootMiss
                PLP
                SEC
                RTS                                 ; X = #_fsStatBuf
@fs_rootMiss    ; THE MOUNTED ROOT'S ANSWER IS FINAL: nothing answers after
                ; it.  The errno goes back unfolded, ENXIO ("no root mounted")
                ; included -- there is no second filesystem left for that case
                ; to fall through to.
                ;
                ; A WRONG ERRNO IS NOT COSMETIC, because callers BRANCH on it.
                ; ENOENT is the answer that tells a program the name is free
                ; rather than unreadable, which is the difference between
                ; creating a file and giving up.
                PLP
                CLC
                RTS                                 ; A = the root's own errno



;==============================================================================
; Fs_Chdir — change the current working directory.
;
; Input:  X = ptr to null-terminated path string (bank $02).
; Output: C=1 ok (_fsCwd updated, trailing '/' ensured).
;         C=0 + A = errno on error:
;           ENOENT, ENAMETOOLONG, EINVAL, EIO   (passthrough from Fs_Stat)
;           ENOTDIR                              (target is not a directory)
;==============================================================================
Fs_Chdir        MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--------------------------------------------------------------
                ; Step 1: Stat the path. On error pass errno through.
                ;
                ; THE PATH RIDES THE STACK ACROSS THE STAT, because Fs_Stat
                ; does not preserve X: `_Fs_RootStat' returns `LDX #_fsStatBuf'
                ; on success -- that IS its contract, the buffer it filled --
                ; and step 2b below needs the caller's name again.
                ;--------------------------------------------------------------
                PHX                             ; save the path ptr
                JSR     Fs_Stat
                BCS     @chd_ok
                PLX                             ; drop the saved path
                PLP
                CLC                             ; re-assert C=0 after PLP
                RTS                             ; A = errno from Fs_Stat

@chd_ok
                ;--------------------------------------------------------------
                ; Step 2: the mode's type field must be S_IFDIR.
                ;--------------------------------------------------------------
                REP     #$20
                MX      %00
                LDA    |_fsStat_Mode
                AND     #S_IFMT
                CMP     #S_IFDIR
                BEQ     @chd_isDir
                PLX                             ; drop the saved path
                PLP
                CLC
                LDA     #ENOTDIR
                RTS

@chd_isDir      MX      %00                 ; 16-bit from the REP above
                ;--------------------------------------------------------------
                ; Step 2b: CANONICALISE, because step 1 may not have.
                ;
                ; `_fsPathScratch' is Path_Resolve's output and step 3 below
                ; copies it into the cwd -- but Fs_Stat only fills it on the
                ; LEGACY arm.  When the mounted root serves the stat the hook
                ; runs BEFORE Path_Resolve is entered at all, so the scratch
                ; still holds whatever the last resolve left there, and chdir
                ; published THAT as the working directory.  Measured: on a
                ; 2.11BSD root `cd /root' followed by `pwd' answered
                ; `/etc/modload.conf', the previous walk's path.
                ;
                ; AFTER THE STAT AND NOT BEFORE IT, which is the whole reason
                ; this is safe.  Path_Resolve is pure string work over `_fsCwd'
                ; -- no block I/O, nothing that sleeps -- but the stat above
                ; CAN sleep, and holding a shared scratch buffer across a sleep
                ; is the hybrid hazard `_Fs_RootOpen's header exists to refuse.
                ; Resolving here means the buffer is written and read with
                ; nothing in between.
                ;
                ; A FAILURE HERE CANNOT HAPPEN AFTER A SUCCESSFUL STAT -- the
                ; name resolved once already -- but it is propagated rather
                ; than assumed, because the two paths need not agree forever.
                REP     #$30
                MX      %00
                PLX                             ; X = the caller's path again

                ; --- THE ROOT'S CWD IS A VNODE, AND THIS IS WHERE IT MOVES ---
                ; Reno's chdir(2) is `chdirec' plus `vrele(ni_cdir);
                ; ni_cdir = ni_vp' -- one referenced vnode, which namei's
                ; relative arm then reads.  root_chdir does that half; the
                ; string below stays for `pwd' until getcwd is converted, so
                ; the two are kept in step here rather than one replacing the
                ; other mid-campaign.
                ;
                ; THE RESULT IS NOT TESTED, on purpose.  ENXIO means no root of
                ; ours and the legacy cwd string is the whole answer, which is
                ; every ProDOS machine; any other error means the name did not
                ; resolve over there, and the stat above already accepted it,
                ; so the legacy arm is the one to believe.  A chdir that
                ; half-succeeds is worse than one that disagrees.
                PHX                             ; the path, across the call
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; name: pad
                PHK                             ;       bank -- the LIVE one
                REP     #$30
                MX      %00
                LDA     3,S                     ;       offset (the saved path)
                PHA
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp909         JSL     KFAR_VFS_ROOTCHDIR      ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #6                      ; drop the copy -- caller cleans
                TCS
                PLX                             ; X = the caller's path again

                ; THE VNODE IS THE CWD, AND IT IS THE ONLY COPY.  vfs_chdir
                ; stored it above; nothing here has to be kept in step with it
                ; any more.  getwd(3) is 2.11BSD's own tree walk over
                ; opendir/readdir now (lib/libc/gen/getwd.c 5.2), so the kernel
                ; keeps no cwd STRING, there is no per-task slot to copy into,
                ; and Path_Resolve has no caller.  apple/fgx#344.

                ; AND THE ANSWER IS THE VFS's, which it had not been: this
                ; returned SEC unconditionally and threw root_chdir's errno
                ; away, so chdir(2) could not report ANY failure the vnode
                ; layer found -- the shape `_Sys_Open' had when it read only
                ; the carry and opened a file the check had refused.  It is
                ; visible the moment a refusal exists: with chdir(2)'s VEXEC
                ; check in, tcsh set $cwd to a directory the kernel had
                ; declined to enter, while pwd -- which asks the kernel --
                ; still named the old one.  Fs_Stat's arm above is the idiom.
                TYA
                BNE     @chd_err
                PLP
                SEC
                RTS
@chd_err        PLP
                CLC
                RTS

;==============================================================================
; Fs_Open / Fs_Read / Fs_Close — single-slot file I/O (seedling only).
;
; fd=3 (FS_FD_FILE) is the one-and-only file descriptor.
; State lives in _fsFileState (see include/memmap.s).
;==============================================================================


;==============================================================================
; Fs_Open — open a file for reading.
;
; Input:  X = offset of a null-terminated path string.  Its BANK is the
;             caller's DBR -- for every caller that is the kernel bank, which
;             is also where Fs_Open's own statics live.  A caller running in
;             another bank cannot satisfy both halves of that with one DBR and
;             must copy the path into the kernel bank first; the far-kernel-bank
;             shim does exactly that (src/kernel/far_shims.s).
; Output: C=1 + A=3 (FS_FD_FILE) on success.
;         C=0 + A=errno on error (EMFILE, EISDIR, ENOTSUP, or passthrough
;                                 from Fs_Stat).
;
; MX:       Caller %00.  Preserves M/X via PHP/PLP.
; Clobbers: A, X, Y, _shTmp0/1/2, _fsTmp0/1/2, _fcbPtr,
;           _libcTmp2 (transitive via _Fcb_Alloc → Kmalloc.  Caller MUST
;           re-establish if used.),
;           _blkBuf, _blkNum, _devPtr, _kmallocResult, _fsStat*,
;           _fsFileState (initialized for the open file).
;==============================================================================

;------------------------------------------------------------------------------
; _Fs_RootOpen - open an ABSOLUTE path against the mounted root, if there is
; one.  UFS campaign 2.4.
;
; THE HOOK IS AT AN ENTRY POINT AND NOT INSIDE ONE, which is the campaign's own
; rule.  The hazard it exists for is a HYBRID that resolves through
; Path_Resolve -- holding `_fsPathScratch' -- and then calls a VFS path that can
; sleep.  This runs BEFORE Path_Resolve has been entered at all, and on a miss
; it returns without having touched the resolver's state.  `_Sys_DevOpen' sat
; in the same relation to `_Sys_Open' and carried the argument; it went with
; the /dev volume on 2026-09-05 and syscall.s keeps the note where it stood.
;
; A MISS FALLS THROUGH AND DOES NOT FAIL, exactly as the /dev hook does.  A
; machine whose boot volume is ProDOS has no root mounted, `root_open' answers
; ENXIO, and every path still reaches the legacy resolver -- so this can only
; add a capability.  That is what lets it land while the ProDOS image is the one
; the suite boots.
;
; THE MODE IS THE CALLER'S NOW, WHICH IS WHAT MADE THE ROOT WRITABLE
; (apple/fgx#318).  This used to push a hardcoded FREAD and say so, because
; `Fs_Open's signature carries no O_ flags and the callers that mattered were
; the kernel's own readers -- `Load_Binary' for /etc/init and for every execve,
; and `Mod_LoadConf'.  Those callers still pass FS_FREAD and still get exactly
; what they got before; `_Sys_Open' passes the flags the user named, which is
; the conversion that header predicted would arrive.
;
; AND THE CREATE COMES FOR FREE WITH IT, which is why no `root_create' hook
; exists beside `root_stat' and `root_listdir'.  In BSD, open(2) with O_CREAT
; IS the create: `vn_open' honours FCREAT, FEXCL and FTRUNC itself and calls
; VOP_CREATE on the not-found arm (4.3BSD-Reno kern/vfs_vnops.c; this tree's
; port is src/kernel/vfs/vfs_vnops.c:196).  Only unlink, mkdir and rmdir are
; separate syscalls that still need hooks of their own.
;
; THE PATH AND THE MODE ARE BOTH STASHED ON THE STACK ACROSS `_Fcb_Alloc',
; which Kmallocs and therefore clobbers A, X AND Y -- the same clobber
; `@fo_notDev' spells out below, and the reason the mode cannot simply stay in
; a register.  It is NOT read from `_Sys_OpenFlags' here even though that cell
; holds it: this routine has a second caller that is not a syscall, and a
; global would hand `Load_Binary' whatever flags the last open(2) happened to
; leave behind -- an execve that quietly CREATES the binary it cannot find.
;
; THE CREATE MODE RIDES IN Y, AND IT IS ALREADY MASKED.  `_Sys_Open' has run
; it through `_Sys_ApplyCmask' and Reno's `& 07777 &~ S_ISVTX' before this is
; reached, so what arrives is the mode to write into the inode -- not the one
; the user typed.  It goes on the stack with the other two for `_Fcb_Alloc's
; clobber, and it is read only on the create arm, over in `vn_open'.  The
; second caller -- Fs_Open's own root hook, serving Load_Binary and
; Mod_LoadConf -- passes zero, having no O_ flags and never creating.
;
; In:  X = path offset in THIS bank.  A = fmode (Reno's FS_F* -- flags + 1).
;      Y = cmode, masked.  MX %00.
; Out: C=1 + A = fd.  C=0 and the caller carries on with the legacy resolver.
;------------------------------------------------------------------------------
_Fs_RootOpen    MX      %00
                PHP
                REP     #$30
                MX      %00
                ; ABSOLUTE OR RELATIVE, BOTH NOW.  This used to refuse a
                ; name whose first byte is not `/', because `root_open' passed
                ; a null starting directory and a relative path would have been
                ; walked from a directory the call never chose.  It chooses one
                ; now -- the PROCESS's, Reno's u.u_cdir, which vfs.mod keeps
                ; and root_open asks for.  namei's relative arm has always been
                ; there (`dp = ndp->ni_cdir', vfs_lookup.c); nothing in this
                ; tree had ever put a vnode in it.
                ;
                ; NOT Path_Resolve, WHICH CANNOT DO THIS.  The canonicaliser
                ; UPPERCASE-FOLDS every component (path.s:567) because ProDOS
                ; is case-insensitive, and 2.11BSD names are bytes -- measured,
                ; `.profile' came back `/ROOT/.PROFILE'.  There was never a
                ; resolver to write: namei is the resolver and it was already
                ; ported.  What was missing was the directory to start from.
                PHA                             ; the fmode, across _Fcb_Alloc
                PHX                             ; the path, across _Fcb_Alloc
                PHY                             ; the cmode, across _Fcb_Alloc
                JSR     _Fcb_Alloc              ; C=1 + A = fd, or EMFILE
                BCS     @fro_haveFd
                PLY                             ; drop the cmode
                PLX                             ; drop the path
                PLY                             ; drop the fmode -- PLY and not
                                                ;   PLA because A is _Fcb_Alloc's
                                                ;   EMFILE and the caller may read
                                                ;   it; Y is dead here.
                BRA     @fro_no
@fro_haveFd     AND     #$00FF
                PHA                             ; the fd, for the return

                ; root_open(pid, fd, name, fmode, cmode), fcc right to left:
                ; cmode goes down first and pid ends nearest the return.
                ; TWELVE argument bytes, which is what the seam entry drops --
                ; it was ten before the mode was carried, and include/kfar.s's
                ; slot 45 comment records the width both sides must agree on.
                ; A SHORT COUNT IS SILENT: the callee builds its frame from
                ; whatever lies under the last push and nothing diagnoses it.
                LDA     3,S                     ; cmode, ALREADY MASKED
                PHA
                LDA     9,S                     ; fmode, AS THE CALLER CHOSE IT
                PHA                             ;   (see the header)
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; name: pad
                PHK                             ;       bank -- the LIVE one,
                                                ;       never a `^' literal
                REP     #$30
                MX      %00
                LDA     11,S                    ;       offset (the saved path)
                PHA
                LDA     9,S                     ; fd (the saved copy)
                PHA
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp906         JSL     KFAR_VFS_ROOTOPEN       ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #12                     ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @fro_fail

                PLA                             ; A = fd
                PLY                             ; drop the saved cmode
                PLX                             ; drop the saved path
                PLY                             ; drop the saved fmode
                PLP
                SEC
                RTS

@fro_fail       ; No such name under the root, or no root at all.  GIVE THE
                ; DESCRIPTOR BACK before answering, for the reason the /dev
                ; hook gives: _Fcb_Alloc took an fd, an FCB and a `struct
                ; file', and whatever answers next allocates its own.
                ;
                ; THE ERRNO COMES OUT IN A, AND ZERO MEANS "NOT MINE".
                ; root_open answers ENXIO when this kernel has no mounted root
                ; and its header says what that is: "a routing answer, not a
                ; user-visible one".  Every other errno is the mounted root's
                ; own answer about a name it owns.  Callers that can fall
                ; through test for zero; the carry is unchanged, so a caller
                ; that only reads the carry behaves exactly as before.
                ;
                ; THE ERRNO RIDES THE STACK AND NOT A REGISTER: _Fcb_Free
                ; clobbers A, X AND Y (fcb.s:358, transitively through Kfree),
                ; so parking it in Y lost it and this returned garbage.
                PHA                             ; the errno, across _Fcb_Free
                LDA     3,S                     ; A = fd (under the errno)
                SEP     #$20
                MX      %10
                JSR     _Fcb_Free
                REP     #$30
                MX      %00
                PLA                             ; A = the errno again
                PLX                             ; drop the fd
                PLX                             ; drop the saved cmode
                PLX                             ; drop the saved path
                PLY                             ; drop the saved fmode
                CMP     #ENXIO
                BNE     @fro_errOut
                LDA     #0                      ; routing: no root here
@fro_errOut     PLP
                CLC
                RTS

@fro_no         ; Nothing was allocated and nothing was asked of the root, so
                ; this is the "not mine" answer.
                LDA     #0
                PLP
                CLC
                RTS

Fs_Open         MX      %00
                PHP
                REP     #$30
                MX      %00

                ; THE PATH POINTER IS PUSHED FOR THE WALK BELOW, which reads
                ; it back off the stack -- Fs_Stat pops it, Fs_Open reads it at
                ; `1,S'.
                PHX                             ; preserve input path ptr
                SEP     #$20
                MX      %10
@fo_notDev
                REP     #$30
                MX      %00
                ; --- THE ROOT, BEFORE THE LEGACY RESOLVER (UFS 2.4) ---
                ; EVERY PATH REACHING HERE IS AN ORDINARY ONE, device names
                ; included: a device is an inode on the root, so the root is
                ; the right authority for all of them.
                ;
                ; ON A MISS THIS COSTS ONE CALL AND A BRANCH, which is what a
                ; machine with no root mounted pays on every open: _Fs_RootOpen
                ; returns C=0 without touching the resolver's state.
                LDA     1,S                     ; the saved path ptr (pre-step
                TAX                             ;   PHX; still the top of stack)
                LDA     #FS_FREAD               ; AND ONLY FREAD, for the reason
                                                ;   the header gives: this site's
                                                ;   callers are the kernel's own
                                                ;   readers and carry no O_ flags.
                LDY     #0                      ; and so no create mode either
                JSR     _Fs_RootOpen
                BCC     @fo_rootErr
                PLX                             ; drop the saved path ptr
                PLP
                SEC
                RTS                             ; A = fd, from the root
@fo_rootErr     ; THE MOUNTED ROOT'S ANSWER IS FINAL, and this is the place
                ; it can be: everything above has already had its turn.
                ;
                ; A WRONG ERRNO IS NOT COSMETIC, because callers BRANCH on it.
                ; elvis keeps the filename it was given only when a failed open
                ; reports exactly ENOENT (tmp.c:112); an open that answered EIO
                ; made it print `Can't open' and restart with NO NAME, so
                ; `vi /tmp/vt' answered "Don't know a name for this file --
                ; NOT WRITTEN" to :wq.
                ;
                ; ZERO IS NOT AN ERRNO, so the fold is undone here.
                ; `_Fs_RootOpen' turns root_open's ROUTING answer -- ENXIO, "no
                ; root mounted here" -- into zero, which meant "not mine, ask
                ; whatever answers next".  Nothing answers next, so the caller
                ; gets what root_open actually said.
                CMP     #0
                BNE     @fo_errOut
                LDA     #ENXIO
@fo_errOut      PLX                             ; drop the saved path ptr
                PLP
                CLC
                RTS                             ; A = the root's own errno


;==============================================================================
; _Fs_FsyncFcb -- report the FCB's latched write error exactly once, then clear
; it.  The shared core of fsync(2) and sync(2).
; In:  _fcbPtr = a regular-file FCB.  Caller MX %00.
; Out: C=1 clean / C=0 + A = the latched errno.
;==============================================================================
_Fs_FsyncFcb    MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDY     #FCB_ErrLatch
                LDA     [_fcbPtr],Y
                BEQ     @ffb_clean
                TAX                             ; X.lo = latched errno.  MX-B-OK:
                                                ;   X.hi is stale B and is dropped
                                                ;   by TXA / AND #$00FF below
                LDA     #0
                STA     [_fcbPtr],Y             ; report once -> clear
                REP     #$30
                MX      %00
                TXA
                AND     #$00FF
                PLP
                CLC
                RTS
@ffb_clean      REP     #$30
                MX      %00
                PLP
                SEC
                RTS
@ffb_errA       AND     #$00FF
                PLP
                CLC
                RTS

;==============================================================================
; Fs_Fsync — SYS_FSYNC (#97) backend.  A.lo = fd.
; Regular file -> full flush + Bm_Sync.  Pipe/socket/dir ->
; successful no-op (nothing on-disk to force; POSIX-tolerant).
; Out: C=1 ok / C=0 + A = EBADF/EIO.
;==============================================================================
Fs_Fsync        MX      %00
                PHP
                REP     #$30
                MX      %00
                AND     #$00FF
                STA     _ffsFd                  ; _Fcb_LookupPtr clobbers A and
                                                ;   _shTmp0; the seam below needs
                                                ;   the fd back
                SEP     #$20
                MX      %10
                LDA     _ffsFd
                JSR     _Fcb_LookupPtr          ; A.lo = fd -> _fcbPtr
                BCS     @ffs_found
                REP     #$30
                MX      %00
                LDA     #EBADF
                PLP
                CLC
                RTS
@ffs_found      MX      %10
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                AND     #FCB_FL_PIPE+FCB_FL_SOCKET+FCB_FL_DIR
                REP     #$30
                MX      %00
                BNE     @ffs_noop
                JSR     _Fs_FsyncFcb            ; the deferred write-error latch,
                BCC     @ffs_err                ;   reported once
                ; AND NOW FORCE THE INODE OUT, which is what fsync(2) is for.
                ; A regular file's DATA is already on the platter -- ufs_write
                ; bwrites every buffer it fills before it returns
                ; (ufs_vnops.c:636) -- but the INODE is left dirty on purpose:
                ; the write marks IUPD|ICHG and defers the write-back to the
                ; last vrele (ufs_vnops.c:641).  root_fsync reaches ufs_fsync,
                ; which is `iupdat(ip, waitfor)'.  apple/fgx#355.
                LDA     _ffsFd
                AND     #$00FF
                PHA                             ; fd
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid, nearest the return
_kfp900         JSL     KFAR_VFS_FSYNC          ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #4                      ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @ffs_err
@ffs_noop       PLP
                SEC
                RTS
@ffs_err        AND     #$00FF
                PLP
                CLC
                RTS

;==============================================================================
; Fs_SyncAll — SYS_SYNC (#98) backend: walk EVERY task's fd table and fsync
; each open regular-file FCB, then Bm_Sync once.  RefCount-shared FCBs get
; flushed more than once — idempotent (the second finds it clean).  Errors
; are best-effort: they stay latched on their FCBs for the owner's next
; write/fsync/close (a caller who cares uses fsync(fd)).  Always C=1.
;
; Loop state rides the STACK ([tcb offset][fd index], read back via
; stack-relative addressing) because _Fs_FsyncFcb's switch+dispatch clobbers
; essentially every scratch cell (_libcTmp2, _sh/_fsTmp*, _fcbPtr).
;==============================================================================
Fs_SyncAll      MX      %00
                PHP
                REP     #$30
                MX      %00
                LDX     #FGX_TASK_TBL_OFF
@fsa_task       LDA:    TCB_Status,X
                BEQ     @fsa_nextT              ; 0 = free slot
                CMP     #TASK_ZOMBIE
                BEQ     @fsa_nextT
                PHX                             ; 3,S = tcb offset
                ; From fd 0: a REGULAR FILE can legitimately occupy 0/1/2 (any
                ; `cmd > file` dup2s it onto fd 1), and starting at 3 silently
                ; excluded exactly those from sync-all.  Pipe/socket/dir FCBs
                ; are skipped by FLAG below, not by index.
                LDA     #0
                PHA                             ; 1,S = fd index (16-bit push)
@fsa_fd         LDA     3,S                     ; re-derive per pass — the
                TAX                             ;   fsync core clobbers all
                LDA:    TCB_FdTablePtr,X        ; fd-table ptr lo16
                STA     _libcTmp2
                SEP     #$20
                MX      %10
                LDA:    TCB_FdTablePtr+2,X      ; bank
                STA     _libcTmp2+2
                REP     #$20
                MX      %00
                LDA     1,S                     ; fd index
                ASL
                CLC
                ADC     1,S                     ; *3 = entry offset
                TAY
                LDA     [_libcTmp2],Y           ; FCB ptr lo16
                STA     _fcbPtr
                INY
                INY
                SEP     #$20
                MX      %10
                LDA     [_libcTmp2],Y           ; bank
                STA     _fcbPtr+2
                REP     #$20
                MX      %00
                LDA     _fcbPtr
                BNE     @fsa_have
                SEP     #$20
                MX      %10
                LDA     _fcbPtr+2
                REP     #$20
                MX      %00
                BEQ     @fsa_nextFd             ; null slot
@fsa_have       SEP     #$20
                MX      %10
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                AND     #FCB_FL_PIPE+FCB_FL_SOCKET+FCB_FL_DIR
                REP     #$20
                MX      %00
                BNE     @fsa_nextFd             ; not a regular file
                JSR     _Fs_FsyncFcb            ; best-effort; C ignored
@fsa_nextFd     PLA                             ; fd index
                INC
                CMP     #FS_MAX_FDS
                PHA
                BCC     @fsa_fd
                PLA                             ; drop fd index
                PLX                             ; tcb offset back
@fsa_nextT      TXA
                CLC
                ADC     #TCB_SIZE
                TAX
                CPX     #FGX_TASK_TBL_OFF+{TASK_MAX_SLOTS*TCB_SIZE}
                BCC     @fsa_task
                PLP
                SEC
                RTS

;==============================================================================
; Fs_Read / Fs_ReadN -- THE LEGACY FILE READER, WHICH READS NOTHING.
;
; Both answered from `_fsFileState' and the FST, and both have gated on
; `FCB_StorageType' since the per-FCB migration.  Nothing writes that field:
; it was prodos.mod's in-use marker and the last writer left with the module,
; so it is zero for every descriptor and EBADF is the only answer either of
; these can give.  A UFS descriptor never arrives here at all -- `_Sys_Read'
; resolves f_ops and crosses to `vfs_read' (`_kOpsVnode's FO_READ slot is
; deliberately zero), and the program loader asks `_Ld_FdIsVnode' and takes
; `_Ld_VnodeRead'.
;
; TWO CALLERS STILL COME HERE AND ARE BROKEN BY IT, each with an issue:
; `_Ifnet_LoadHwaddr' (ifconfig_sys.s) reads /etc/hwaddr.conf and takes the
; EBADF for end-of-file, so the file is silently ignored -- apple/fgx#356;
; `Con_LoadFontFromFile' reports it to font(1), which cannot load any font on
; the image -- apple/fgx#357.  Both fixes move the read off this path, and
; these two routines go when the second of them lands.
;
; Contract, unchanged: C=0 + A=errno.  A=0 would mean EOF and is never
; returned.
;==============================================================================
Fs_Read         MX      %00
Fs_ReadN        ENT
                PHP
                REP     #$30
                MX      %00
                LDA     #EBADF
                PLP
                CLC
                RTS


;==============================================================================
; Fs_Close — close the file fd and free the slot.
;
; Input:  A = fd (must be 3).
; Output: C=1 ok. C=0 + A=EBADF on error.
;
; MX:       Caller %00.  Preserves M/X via PHP/PLP.
; Clobbers: A, X, Y, _shTmp0, _fcbPtr,
;           _libcTmp2 (transitive via _Fcb_Free → Kfree — caller MUST
;           re-establish if used).  May call _Fs_FlushOnClose (if dirty)
;           which additionally clobbers _blkBuf/_blkNum/_devPtr/_fsTmp*.
;==============================================================================
Fs_Close        MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--------------------------------------------------------------
                ; Validate fd via _Fcb_LookupPtr.  Stash fd on the stack
                ; because _Fcb_LookupPtr clobbers _shTmp0 internally.
                ;--------------------------------------------------------------
                AND     #$00FF
                SEP     #$20
                MX      %10
                PHA                             ; stack: fd (1 byte, M=1)
                JSR     _Fcb_LookupPtr
                BCS     @fc_open
                ; EBADF — drop saved fd (1 byte, M=1), return errno.
                STA     _shTmp0                 ; preserve errno
                PLA                             ; drop saved fd
                LDA     _shTmp0
                REP     #$20
                MX      %00
                LDA     _shTmp0
                AND     #$00FF
                PLP
                CLC
                RTS
@fc_open        MX      %10
                ; A /dev DESCRIPTOR PASSES THROUGH HERE, AND THAT IS MEASURED
                ; RATHER THAN ASSUMED -- UFS 1.7d I3.
                ;
                ; A descriptor opened under /dev is a vnode whose f_ops are in
                ; the FAR bank, and the read, write and ioctl sites all have to
                ; discriminate on that because they JUMP to an arm.  Close does
                ; not: the vnode's teardown is already wired underneath, since
                ; _Fcb_Free ends in kdesc_free -> fdrelease -> closef ->
                ; fo_close, and fo_close on a vnode is vn_close in vfs.mod.
                ;
                ; SO THE ONLY QUESTION IS WHETHER THE ProDOS HALF BELOW HARMS
                ; ONE, AND TODAY IT CANNOT.  Its FCB is the zeroed, typeless one
                ; _Fcb_Alloc made: FCB_FL_DIRTY is clear so nothing flushes,
                ; FCB_ErrLatch is clean, and prodos.mod's _fop_close only
                ; unpins FCB_DataBuf/IdxBuf/MasterBuf, which its own header says
                ; are "no-ops when no pin is held".  A discriminating arm was
                ; written here first and then removed: MUTATING IT AWAY -- every
                ; vnode close routed through the legacy teardown -- left smoke,
                ; devnode and devfallthru all green, which is the tree's own
                ; signal that a case cannot fail.  Keeping it would have cost a
                ; _Fcb_OpEntry call on every close of every descriptor to buy
                ; nothing observable.
                ;
                ; WHAT WOULD MAKE IT STOP BEING TRUE: a device FCB that carries
                ; ProDOS state, or a _fop_close that does more than unpin.  The
                ; arm comes back with the first of those, and it comes back with
                ; a witness, which is what it did not have.
                ; Chardev fast path: skip the SwitchToFCB / flush / FOP
                ; dispatch dance — chardev FCBs have no on-disk state,
                ; no flush, no per-mount mapping.  Notify the chardev op
                ; (best-effort, ignore result) then free the FCB.
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                JSR     _Fcb_ClassifyFlags

                ; DISPATCH THROUGH A PER-TYPE TABLE -- UFS 1.7d I2c.
                ;
                ; M NARROWS AGAIN BEFORE THE JUMP.  Every arm here declares
                ; MX %10 and begins with 8-bit work, so the width the index
                ; arithmetic needs is given back before the jump rather than
                ; pushed into every arm.  X carries the index and is not an
                ; argument to any of them.
                REP     #$30
                MX      %00
                AND     #$00FF
                ASL                             ; DA entries, two bytes each
                TAX
                SEP     #$20
                MX      %10
                JMP     (@fc_opsTbl,X)

; Indexed by DTYPE_*, so the order IS the DTYPE_* block in include/fs.s.
@fc_opsTbl      DA      @fc_normal              ; 0: not a type
                DA      @fc_normal              ; 1: DTYPE_VNODE -- file or dir
                DA      @fc_socket              ; 2: DTYPE_SOCKET
                DA      @fc_pipe                ; 3: DTYPE_PIPE

@fc_socket      MX      %10                     ; socket fast path (no flush/FOP)
                ; TEAR DOWN ONLY ON THE LAST REFERENCE, exactly as the pipe
                ; arm below already does -- this was the
                ; one descriptor type that did not ask.  A socket fd inherited
                ; across spawn or duplicated by dup2 shares ONE FCB
                ; (_Fcb_InheritRefs, _Fd_Dup), so the FIRST close of ANY holder
                ; destroyed the connection under every other one.
                ;
                ; telnetd is the customer: it spawns getty on the pty with file
                ; actions, the child inherits the accepted connection, and the
                ; child's close of its copy tore the socket down in the PARENT.
                ; The session then ended the moment the login shell touched it
                ; -- the shell had started and run (measured: a full 78-page
                ; tcsh stack, high-water 2982) before the connection died under
                ; it, which is why this looked like the shell exiting rather
                ; than the socket being pulled out from beneath it.
                LDY     #FCB_RefCount
                LDA     [_fcbPtr],Y
                CMP     #2
                BCS     @fc_sockShared          ; >=2 -> another fd still holds
                                                ;   it; just drop this slot
                REP     #$20
                MX      %00
                ; Loopback sockets are torn down kernel-side: their state is two
                ; pipe.s rings, not a W5100 socket, and net.mod cannot reach
                ; pipe.s.  _Loop_CloseTry leaves _loopHandled=0 for hw sockets.
                LDY     #FCB_SockIdx
                LDA     [_fcbPtr],Y
                AND     #$00FF
                TAY
                JSR     _Loop_CloseTry
                LDA     _loopHandled
                BNE     @fc_sockdone
                LDY     #NETOP_SockTeardown     ; _Sock_Teardown now in net.mod
                JSR     _Net_Dispatch           ; -> net_op_sockteardown (_fcbPtr live)
@fc_sockdone
                SEP     #$20
                MX      %10
@fc_sockShared  PLA                             ; restore fd from stack
                JSR     _Fcb_Free
                REP     #$20
                MX      %00
                PLP
                SEC
                RTS
@fc_pipe        MX      %10                     ; pipe fast path (no flush/FOP).
                ; Tear the pipe down only when the LAST reference to THIS end
                ; closes (refcount hits 0).  Pipe ends are dup'd by the shell, so
                ; an early teardown would free a ring the surviving dup still uses.
                LDY     #FCB_RefCount
                LDA     [_fcbPtr],Y
                CMP     #2                      ; >=2 -> another fd still shares this end
                BCS     @fc_pipeShared
                REP     #$20
                MX      %00
                JSR     _Pipe_Teardown          ; mark end closed, wake peer, free if both gone
                SEP     #$20
                MX      %10
@fc_pipeShared  PLA                             ; restore fd from stack
                JSR     _Fcb_Free               ; decrement refcount; frees FCB at 0
                REP     #$20
                MX      %00
                PLP
                SEC
                RTS
; The shared-close exit for a regular file, placed BEFORE the arm so the gate's
; BCS is a short backward branch: the body below is far longer than a relative
; branch reaches.
@fc_nmShared    PLA                             ; restore fd from stack
                JSR     _Fcb_Free               ; decrement refcount; frees at 0
                REP     #$20
                MX      %00
                PLP
                SEC
                RTS
@fc_normal      MX      %10
                ; TEAR DOWN ONLY ON THE LAST REFERENCE, exactly as the chardev,
                ; socket and pipe arms above already do.  This was the one
                ; descriptor type of the four that never asked (apple/fgx#138),
                ; and unlike the other three the consequence was not a resource
                ; released early but SILENT DATA LOSS: the close tore the file
                ; state down under a surviving dup, so a write through it landed
                ; in a slot nobody owned.  Measured -- write() returned the right
                ; count, the file's EOF grew by exactly that much, and the bytes
                ; on disk were ZEROS.  A caller checking write()'s result and a
                ; reader checking the file's size both saw success.
                ;
                ; THE ERROR LATCH IS WHY THE GATE GOES HERE AND NOT LOWER DOWN.
                ; FCB_ErrLatch is per-FCB and the body below CONSUMES it (reads
                ; it, zeroes it, reports it).  Doing that on a non-final close
                ; would swallow a deferred write error that belongs to whoever
                ; closes last -- trading a loud defect for a quiet one, which is
                ; the trap this arm's shape sets for a fix applied further in.
                LDY     #FCB_RefCount
                LDA     [_fcbPtr],Y
                CMP     #2
                BCS     @fc_nmShared            ; >=2 -> another fd still holds it
                ; F4: pull the deferred write-error latch BEFORE the FCB is
                ; freed; it rides the stack to the tail and reports as
                ; C=0 + A=errno (the close itself still completes fully).
                SEP     #$20
                MX      %10
                LDY     #FCB_ErrLatch
                LDA     [_fcbPtr],Y
                PHA                             ; [latch] (0 = clean)
                LDA     #0
                STA     [_fcbPtr],Y
                ; THERE IS NO FLUSH HERE, because there is nothing buffered to
                ; flush.  A vnode descriptor's teardown runs underneath --
                ; _Fcb_Free -> kdesc_free -> fdrelease -> closef -> fo_close ->
                ; vn_close -- and its data is already on the platter, ufs_write
                ; bwriting every buffer it fills before it returns
                ; (ufs_vnops.c:636).  What remains owed at close is the INODE,
                ; which vrele's ufs_inactive writes back.
                ; Free the fd-table slot.
                ; THE LATCH STAYS ON THE STACK ACROSS _Fcb_Free, and no
                ; scratch cell will do: the teardown underneath reaches a
                ; driver's d_close, and pty.mod's `_Pty_PairFromMinor' parks A
                ; in _shTmp2 -- the last byte written to any chardev, so every
                ; pty close answered errno 10, the `\n' of the line printed
                ; before it (apple/fgx#352).
                LDA     2,S                     ; the fd, under [latch]
                JSR     _Fcb_Free
                PLA                             ; F4: latched errno (0 = clean)
                XBA                             ; ...parked in B
                PLA                             ; drop the fd
                XBA                             ; A.lo = the latch again
                REP     #$20
                MX      %00
                AND     #$00FF
                BEQ     @fc_clean
                PLP                             ; A = latched errno; close DID
                CLC                             ;   complete — this reports the
                RTS                             ;   earlier lost write, once
@fc_clean       PLP
                SEC
                RTS

;==============================================================================
; Fs_Lseek -- POSIX lseek(fd, offset, whence) -> the new position.
;
; THE OFFSET IS A SIGNED 32-BIT off_t, which is 2.11BSD's own width:
; `typedef long off_t' (usr/sys/h/types.h:46).  Upstream's lseek() declares
; its argument `off_t off' and does `case L_INCR: fp->f_offset += uap->off'
; with no range check (usr/sys/sys/ufs_syscalls2.c:211), so a backwards
; SEEK_CUR is ordinary there and is ordinary here.
;
; Input (caller MX %00, DBR=kernel-bank; $02 = assembly ORG):
;   A          = fd (low byte)
;   X          = offset bits 0..15
;   Y          = offset bits 16..31
;   _fsLsWhence = whence (SEEK_SET=0, SEEK_CUR=1, SEEK_END=2)
;
; Output:
;   C=1 + A = newpos.lo16, Y = newpos.hi16.
;   C=0 + A = errno (EBADF, ESPIPE, EINVAL, EIO).
;
; Note: the high byte rides home in Y because the JSL syscall dispatcher's
; exit path does `LDX _Sys_UserSP / TXS` and overwrites X.  Y is untouched
; on the way out, so userland can `TYA` the high byte after the JSL.
;
; MX:       Caller %00.  Preserves M/X via PHP/PLP.
; Clobbers: A, X, Y, _shTmp0/1/2, _fsTmp0/1/2, _fcbPtr, _libcTmp2.
;==============================================================================
; _flsOff / _flsNew / _flsBase / _flsFd / _fsLsWhence live in memmap.s.

; _Fs_RootLseek - vfs_lseek(pid, fd, off, whence, resultp) across the seam.
;
; FOURTEEN ARGUMENT BYTES, which is what the seam entry drops: two ints, a
; long, an int and a pointer.  fcc pushes right to left, so `resultp' goes
; down first and `pid' ends nearest the return.
;
; THE LONG GOES DOWN HIGH WORD FIRST, because its low word must end at the
; LOWER address and the stack grows down.  _flsOff is already the 32-bit
; offset Fs_Lseek assembled from X and Y.
;
; THE RESULT COMES BACK IN _flsNew, this bank's own cell, which is why the
; pointer's bank is PHK's LIVE one and never a `^' literal: the kernel is
; relocated and @fl_modOK reads _flsNew from wherever that is.
;
; Out: C=1 and _flsNew holds the new offset.  C=0 and _shTmp0 = errno.
_Fs_RootLseek   MX      %00
                PHP
                REP     #$30
                MX      %00
                SEP     #$20
                MX      %10
                LDA     #0
                PHA                             ; resultp: pad
                PHK                             ;          bank -- the LIVE one
                REP     #$30
                MX      %00
                PEA     _flsNew                 ;          offset
                LDA     _fsLsWhence
                AND     #$00FF
                PHA                             ; whence
                LDA     _flsOff+2
                PHA                             ; off, high word first
                LDA     _flsOff
                PHA                             ;      then low
                LDA     _flsFd
                AND     #$00FF
                PHA                             ; fd
                JSR     _Fcb_OwnerPid           ; not _curTask -- see fcb.s
                PHA                             ; pid
_kfp973         JSL     KFAR_VFS_LSEEK          ; bank byte patched by Far_Init
                TAY                             ; park the errno; TSC needs A
                TSC
                CLC
                ADC     #14                     ; drop the copy -- caller cleans
                TCS
                TYA
                BNE     @frl_err
                PLP
                SEC
                RTS
@frl_err        AND     #$00FF
                STA     _shTmp0
                PLP
                CLC
                RTS

Fs_Lseek        MX      %00
                PHP
                REP     #$30
                MX      %00

                ;--- Capture args.  fd in A.lo, offset.lo16 in X, offset.hi16
                ;    in Y.  Stash into stable bank-$02 cells the module reads.
                ;
                ;    ALL SIXTEEN BITS OF Y ARE THE HIGH WORD, and that is what
                ;    makes a backwards seek expressible: lseek(fd, -8L,
                ;    SEEK_CUR) arrives as X=$FFF8, Y=$FFFF and must assemble to
                ;    -8 rather than to +16,777,208. ---
                STA     _flsFd
                STX     _flsOff
                STY     _flsOff+2
                STZ     _flsNew
                STZ     _flsNew+2

                ;--- Validate fd via _Fcb_LookupPtr. ---
                SEP     #$20
                MX      %10
                LDA     _flsFd
                JSR     _Fcb_LookupPtr
                BCS     @fl_fdOK
                STA     _shTmp0
                JMP     @fl_err

@fl_fdOK        ;--- Reject dir FCBs with ESPIPE. ---
                LDY     #FCB_Flags
                LDA     [_fcbPtr],Y
                AND     #FCB_FL_DIR
                BEQ     @fl_canSeek
                LDA     #ESPIPE
                STA     _shTmp0
                JMP     @fl_err

@fl_canSeek     REP     #$20
                MX      %00

                ;--- THE ROOT'S SEEK, BEFORE THE LEGACY FST -- apple/fgx#322 ---
                ; A descriptor on the mounted root keeps its offset in the VFS
                ; file pool's f_offset, which is what vfs_read and vfs_write
                ; advance.  _Fst_Dispatch below moves a DIFFERENT number -- the
                ; legacy FCB's -- so a seek used to leave the reads exactly
                ; where they were.  That is `vi': elvis writes two header
                ; blocks, rewinds with lseek(fd, 0, SEEK_SET) and re-reads
                ; them, and got 0 bytes back from a file position still at
                ; EOF ("garbage() failed to read oldhdr??", recycle.c:62).
                ;
                ; _Fcb_OpEntry IS ASKED PURELY FOR _fdOpsFar and the slot it is
                ; given does not matter -- resolving f_ops is what sets the
                ; cell, and FO_READ is simply a slot every descriptor has.  A
                ; far answer means the ops live in vfs.mod, which is exactly
                ; the descriptors whose offset this bank cannot reach.
                LDA     _flsFd
                AND     #$00FF
                LDX     #FO_READ
                JSR     _Fcb_OpEntry
                BCS     @fl_notSeekable         ; an in-bank arm: not an inode
                LDA     _fdOpsFar
                BEQ     @fl_notSeekable
                JSR     _Fs_RootLseek
                BCC     @fl_errRep              ; _shTmp0 carries the errno
                BRA     @fl_modOK               ; _flsNew is filled

                ; ESPIPE, WHICH IS UPSTREAM'S ANSWER FOR A DESCRIPTOR THAT IS
                ; NOT A FILE.  2.11BSD `lseek' opens with the same test
                ; (usr/sys/sys/ufs_syscalls2.c:220):
                ;
                ;     if (fp->f_type != DTYPE_INODE) {
                ;             u.u_error = ESPIPE;
                ;             return;
                ;     }
                ;
                ; A far answer above IS "f_type is DTYPE_VNODE": the only
                ; descriptors whose ops live in vfs.mod are the ones backed by
                ; a vnode.  Everything else here -- pipe, socket, chardev -- is
                ; a stream, and a directory was already answering ESPIPE at
                ; `@fl_fdOK'.
@fl_notSeekable LDA     #ESPIPE
                STA     _shTmp0
                BRA     @fl_errRep

@fl_modOK       LDA     _flsNew                 ; new.lo16
                LDY     _flsNew+2               ; new.hi16
                                                ; Y carries hi because syscall
                                                ; dispatcher exit clobbers X.
                PLP
                SEC
                RTS

@fl_err         REP     #$20
                MX      %00
@fl_errRep      LDA     _shTmp0
                AND     #$00FF
                PLP
                CLC
                RTS

;==============================================================================
; END fs.s
;==============================================================================
