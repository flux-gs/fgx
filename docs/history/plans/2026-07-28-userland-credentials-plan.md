# Userland credentials — uid/gid, passwd, login (plan of record, 2026-07-28)

Builds the **process-credential layer** FGX has never had: per-process uid/gid in
the kernel, the `set*id` family, a real passwd database in libc, and the
`login`/`id` userland that consumes them. Prerequisite work for two campaigns
already in flight — the **UFS second FST**
(`2026-07-21-unix-fs-second-fst-plan.md`), whose on-disk inode carries
`di_uid`/`di_gid`/`di_mode` (`:119`) and whose stat path promises "real
`mode/nlink/uid/gid/size/times`" (`:215`), and **telnetd**
(`2026-07-24-telnetd-plan.md`), which scopes login/getty out (`:68`) and
authentication out (`:170`) precisely because none of this exists.

**The one surprise (survey 2026-07-28):** the credential layer is not
"unstarted" — it is **started and disconnected**. `SYS_GETUID` and `SYS_GETGID`
are implemented and dispatched, and have **zero callers in the entire tree**:
libc's `getuid()` is a compiled-in `LDA #0` that never issues the syscall. The
two calls were also absent from `include/loader.s` (the file `include/kernel.s:637`
names authoritative) and from the `userland-abi.md` table. And they sat on
**2.11BSD's `mount`(21)/`umount`(22)** — the two numbers the UFS campaign's P1
needs. So the first work item was not "add credentials," it was "decide what
those two slots are."

> **DECIDED 2026-07-28 (§7.1 option (a)) — LANDED.** getuid → **24**, getgid →
> **47** (their 2.11BSD numbers); **21/22 are now reserved for `mount`/`umount`**
> and dispatch to `_Sys_Stub` (ENOSYS). Both calls gained the `EQU`s they never
> had in `include/loader.s` and now appear in the generated `userland-abi.md`
> table. The move cost nothing — nothing called 21/22.
>
> **P0 is now COMPLETE** (§3): libc issues the real syscalls, and `uidprobe`
> gates it. The disconnected seam described above is closed — userland identity
> is no longer a compile-time constant.

**Estimate: ~4–5 sessions.** ~~P0 (close the seam + renumber) ~0.5~~ **✅ done**;
~~P1 (u-area credentials) ~1~~ **✅ done**; ~~P2 (`set*id`) ~0.5~~ **✅ done**;
P3 (passwd db) ~1, P4 (`login`/`id` + init) ~0.5–1, P5 (mode bits + `chmod`/`umask`) ~1,
P6 (enforcement) deferred behind UFS.

> **KERNEL-SIZE WALL (2026-07-28).** P2 overran the `FGX_CODE..FGX_DATA`
> ceiling (57664 B) by 101 B, with P1 having left only 72 B free. Shrinking P2
> was not viable — `_Cred_Set` alone is ~85 B. Reclaimed **472 B** by compiling
> out `SYS_DIAG` (#54) behind `DIAGSYS EQU 0` (include/fs.s), on the `LATPROBE`
> precedent: it had **no caller anywhere in the tree**, its only consumer
> `kdiag(1)` having lost its source (`src/userland/kdiag/` holds nothing but
> `_FileInformation.txt`), and it is neither built nor covered by a fixture.
> Kernel 57765 → **57293, i.e. 371 B free.** The code is gated, not deleted.
>
> **This wall will return.** P3/P4/P5 all add kernel code, and 371 B does not go
> far. A survey found no other dead code (0 unreferenced labels across 455) and
> the remaining probes (`BLKPROBE`, `INODEPROBE`) are fixture-gated, so the next
> reclamation will have to be structural — moving non-core syscalls out of the
> kernel bank, or raising `FGX_DATA` (measured headroom: ~330 B to the `$02FE00`
> ceiling). Note `memmap.s:918`'s "region now FULL: this was the last spare
> byte" is **stale** — it describes the KGlobals sub-region, and the listing
> puts `KMem_KGlobals_end` at `$02FCB6`, 330 B short.

---

## 1. Grounding (survey 2026-07-28; `main` @ `a6933b03`, toolchain v1.21.0)

Everything below is a code fact with a `file:line` cite.

| Fact | Cite |
|---|---|
| `SYS_GETUID`/`SYS_GETGID` are real, dispatched, working — each a 3-instruction global read. **Renumbered 21/22 → 24/47 on 2026-07-28** (see the DECIDED box above); cites are post-move | `src/kernel/syscall.s:553,576,1691-1716` |
| **Credentials are two kernel globals, not per-process.** Comment already flags it: "when fork/setuid land, these move into the TCB" | `include/memmap.s:148-153` |
| **libc `getuid()` never issues the syscall** — `return 0` in C, `LDA #0` in the compiled body | `toolchain/lib/libc_c/libc_c.c:2508-2511`, `toolchain/lib/libc_c.s:27765` |
| `geteuid()` delegates to `getuid()`; **`getgid`/`getegid` are not provided at all** (explicitly listed as absent) | `libc_c.c:2785`, `toolchain/include/unistd.h:59-69` |
| ~~`SYS_GETUID`/`SYS_GETGID` have no `EQU` in `include/loader.s`~~ — the authoritative numbering file — ~~and no `userland-abi.md` row~~. **FIXED 2026-07-28**: both `EQU`s added; the doc table is *generated* from loader.s by `tools/gen_syscall_table.py` and `build.sh` gates on it | `include/loader.s:165,237`, `include/kernel.s:637` |
| Numbering convention is "follow 2.11BSD `<sys/syscall.h>` where the call exists in BSD" — 21/22 are BSD's `mount`/`umount`, which UFS P1 needs. **Now reserved for it** | `include/loader.s:131-133,159-164`, UFS plan §3.2 |
| **The TCB is exactly full and hard-capped at 64 B** (`ERR` guard); growing it breaks the `ASL x6` (×64) index math in `Task_Alloc`/`Lookup` | `include/kernel.s:246-300` |
| Seven fields already alias unused v3-scheduler fields (`SavedPC`, `SavedPB`, `PendingSig`, `SigIgnore`, `DPHandle`, `StackHandle`, `FdTablePtr`) — **every v3-only field is claimed**; 1 spare pad byte (hi byte of `TCB_CPUTime`) | `include/kernel.s:315-345` |
| **The `SE_` sched-entry table is also exactly full** — fields sum to 32, `DS 32-{*}` yields zero pad. `SE_PGroup` lives here; no room beside it | `include/kernel.s:456-491` |
| **The u-area is the one growable per-task struct** — Kmalloc'd M_KERN, reached via `[_u],Y`, `U_SIZE EQU *` with **no `ERR` guard**, currently 30 B. Self-described "BSD `struct user` analog" | `include/kernel.s:615-631` |
| `fork`(2) and `vfork`(46) are both real; `vfork` children carry a snapshot descriptor (`SE_SnapPtr`) restored at execve/_exit | `include/loader.s:135,213`, `include/kernel.s:474-479` |
| **`_Sys_Stat` returns the LEGACY 15-byte `ST_*` buffer verbatim** — it does not build the BSD layout | `src/kernel/syscall.s:3965-4002`, `include/fs.s:71-87` |
| The 32-byte `STX_*` BSD stat struct **with `STX_uid`/`STX_gid` exists but is dead code** — no writer, no reader | `include/fs.s:576-590` |
| **libc `stat()` is the translation seam**: zeroes the 30-byte POSIX struct (hence `st_uid`/`st_gid` == 0) and synthesizes `st_mode` from the ProDOS mode byte + **access-byte bit 1 (write-enable) → `S_IWUSR`** | `libc_c.c:1462-1495` |
| Mode-bit vocabulary is **2 of 12**: only `S_IRUSR`/`S_IWUSR`. No execute, no group/other, no setuid/setgid/sticky | `include/fs.s:594-599`, `toolchain/include/sys/stat.h:51-54` |
| **Executability is the FGX1/2/3 header magic, not a mode bit** — magic mismatch → `ENOEXEC`; there is no exec-permission concept to enforce | `src/kernel/loader.s:192-202,366` |
| ProDOS access byte is read into `ST_ProFlags` (+8) from `DE_Access`; `$C3` typical (destroy+rename+write+read) | `include/fs.s:76,238`, `src/drivers/fs/fs.s:706,989` |
| **`getpwuid`/`getpwnam` are declared with no implementation anywhere** — a latent link error; `robots` documents the workaround rather than call them | `toolchain/include/pwd.h`, `src/userland/robots/score.c:124` |
| `utmp.h` is likewise headers-only (`struct utmp`, `_PATH_UTMP`, `_PATH_WTMP`) with no files and no accounting | `toolchain/include/utmp.h` |
| **`/etc/passwd`, `/etc/group`, `/etc/utmp`, `/etc/wtmp` do not exist** (18 files staged, none of them these) | `disk_src/etc/` |
| **No `login`, `su`, `id`, `whoami`, `who`, `passwd`, `chmod`, `chown`, `groups`, `newgrp`** among ~180 userland programs; neither shell has `umask` | `src/userland/` |
| `init` is the documented login(8) stand-in: hardcodes `PATH`/`HOME=/root`, `argv[0]="-sh"`, chdir to home. Sets no `USER`/`LOGNAME` | `src/userland/init/init.c:18-31,54-55` |
| `/etc/profile` carries the same "stands in for login(1)" provenance note | `disk_src/etc/profile:5-13` |
| `ls -l` owner/group are hardcoded returns (uid 0 → `"root"`, gid 0 → `"fgx"`, else `"?"`); `Aflg = !getuid()` is a compile-time constant | `src/userland/ls/ls.c:106,550-560` |
| **Enforcement is zero.** The only `EPERM` in the whole kernel refuses `unlink` on a directory. No `suser()`, no credential check in any FS/exec/kill/signal path | `src/drivers/fs/write.s:533` |
| Free dispatch slots: 0, 8, 9, 13–16, 23–27, 29–36, 38, 45, 47 (28 is a declared `SYS_FSTAT` stub) | `src/kernel/syscall.s:528-576` |

---

## 2. Design

### 2.1 Credentials live in the u-area

Both obvious homes are full (§1): the TCB is `ERR`-guarded at 64 B with every
aliasable field already claimed, and `SE_` sums to exactly 32 with zero pad. The
u-area is the remaining option and also the *correct* one — it is explicitly the
`struct user` analog, and 2.11BSD keeps `u_uid`/`u_ruid`/`u_gid`/`u_rgid`/
`u_groups[]` there. It is Kmalloc'd per task with no size ceiling, so growth
costs a slightly larger heap block and nothing else.

```
U_Uid       DS 2    ; effective uid
U_Ruid      DS 2    ; real uid
U_Gid       DS 2    ; effective gid
U_Rgid      DS 2    ; real gid
U_Svuid     DS 2    ; saved-set uid (exec of a setuid image)
U_Svgid     DS 2    ; saved-set gid
```

12 bytes, taking `U_SIZE` 30 → 42. Supplementary groups (`u_groups[NGROUPS]`)
are **deferred** — `getgroups`/`setgroups` are out of scope (§6); a single gid
covers everything UFS and telnetd need.

`_kProcUid`/`_kProcGid` (`include/memmap.s:152-153`) are deleted; `_Sys_GetUid`/
`_Sys_GetGid` re-point at `[_u],Y`. Inheritance:

- **`fork`/`vfork`** — child copies all six fields from the parent. Note the
  `SE_SnapPtr` restore path: the child performs the restore at execve/`_exit`,
  so credential copy must happen at *snapshot* time, not restore time.
- **`execve`/`posix_spawn`** — credentials survive exec unchanged (no setuid
  images until P5/P6; see §5.4).
- **Task slot recycle** — `Task_Alloc` zeroes the u-area, i.e. a fresh slot is
  root. Acceptable while init is the only spawner of unparented tasks; revisit
  if a daemon ever forks without inheriting.

### 2.2 Syscall surface — the 21/22 collision, resolved

The convention (`include/loader.s:131-133`) is BSD numbering where BSD has the
call. 2.11BSD assigns `setuid`=23, `getuid`=24, `setgid`=46, `getgid`=47 — and
`mount`=21, `umount`=22. FGX had put getuid/getgid on 21/22, which followed
nothing and took the two numbers the UFS campaign's `mount(2)` wants.

**Resolved (a): renumbered to BSD 24/47; 21/22 reserved for `mount`/`umount`.**
Landed 2026-07-28 as a table + `EQU` + generated-doc edit with no compatibility
cost, because nothing called 21/22. The map now:

| # | Slot |
|---|---|
| 21, 22 | **RESERVED** — BSD `mount`/`umount`, held for UFS. `_Sys_Stub` → ENOSYS |
| 23 | free — BSD's `setuid`, held for it |
| 24 | `SYS_GETUID` ✅ |
| 47 | `SYS_GETGID` ✅ |

Exact BSD parity is unreachable for the rest: BSD's `setgid`=46 is already spent
on FGX-local `SYS_VFORK`. So `setuid` takes BSD's 23 and **`setgid` goes
FGX-local** — 25 is the natural pick, keeping the credential block contiguous at
23–26 with `seteuid`/`setegid` following.

New calls:

| Call | Semantics |
|---|---|
| `setuid(uid)` | root → sets all three (real/eff/saved). Non-root → permitted only if `uid` matches real or saved; sets effective only. Else `EPERM`. |
| `setgid(gid)` | Same rule on the gid triple. |
| `seteuid`/`setegid` | Effective only, same permission rule. |
| `getgid`/`getegid` | Missing today (`unistd.h:67-69`); add. |

Plus a kernel-internal `_Suser` helper (`u_uid == 0` → C=1) — the single
chokepoint every future enforcement site calls, so P6 has one predicate to
audit rather than N open-coded comparisons.

### 2.3 libc + the passwd database

Three fixes, in dependency order:

1. **Close the seam.** `getuid`/`geteuid` issue the real syscall via
   `__syscall`; add `getgid`/`getegid`; add the four `set*id` wrappers. Drop the
   "not provided" entries from `unistd.h:67-69`.
2. **Implement `getpwnam`/`getpwuid`/`getpwent`/`setpwent`/`endpwent`** over a
   real `/etc/passwd`. `pwd.h` currently declares two of these with no
   implementation — any port that actually calls them link-fails today, which is
   why `robots/score.c:124` hardcodes `"fgx"`. Extend `struct passwd` with
   `pw_passwd`, `pw_gecos`, `pw_shell` (ports read them; `ls`, `login`, and
   `id` all want `pw_name`).
3. **`getlogin()`** from the environment (`USER`), the cheap version — no utmp
   (§6).

`/etc/passwd` format: standard 7-field colon-separated, parsed with the existing
`strsep`-shaped helpers. Staged in `disk_src/etc/passwd`:

```
root:*:0:0:Charlie Root:/root:/bin/sh
```

**Password hashing is out of scope for v1** (§6). The `*` in field 2 means "no
password accepted"; `login` on the console path does not prompt. A real
`crypt(3)` arrives with telnetd's authentication follow-on, not here.

### 2.4 Userland — `login`, `id`, and init's handoff

`init` currently *is* login (`init.c:18-31`): it hardcodes the environment
because there is no passwd file to read it from. With one, the hardcoding
becomes a lookup:

- **`login(1)`** — a real program. Looks up the user, sets uid/gid, builds the
  environment from the passwd entry (`HOME` from `pw_dir`, `SHELL` from
  `pw_shell`, plus `USER`/`LOGNAME` which nothing sets today), chdirs, execs the
  shell as `-sh`. On the console path with a `*` password it does not prompt.
- **`init`** either execs `login` or performs the same lookup inline. Recommend
  **inline for v1** — it keeps the single-process boot path and avoids a getty
  layer FGX doesn't want (`init.c:15-17` already reasons about this).
- **`id`/`whoami`** — small, and the honest gate that credentials work
  end-to-end.
- **`ls`** drops `getname`/`getgroup`'s hardcoded strings (`ls.c:550-560`) for
  `getpwuid`/`getgrgid`, falling back to the numeric id (BSD behavior) when the
  lookup misses. `Aflg = !getuid()` (`:106`) becomes a real runtime test.
- `/etc/profile` keeps working unchanged; its provenance note gets a line saying
  login now supplies what it used to stand in for.

`/etc/group` + `getgrnam`/`getgrgid` come along for `ls -l`'s group column.

### 2.5 Mode bits and `chmod`, over ProDOS

The vocabulary is 2 of 12 (§1). Fill it in — `S_IXUSR`, the group/other triples,
`S_ISUID`/`S_ISGID`/`S_ISVTX` — in both `include/fs.s:594-599` and
`sys/stat.h:52-55`, keeping FGX's 16-bit packing.

On ProDOS the bits map onto the access byte, which is **already a live
permission source**: libc `stat()` reads bit 1 (write-enable) → `S_IWUSR`
(`libc_c.c:1484-1485`). So a ProDOS-era `chmod` is real work, not a stub:

| POSIX | ProDOS access byte |
|---|---|
| `S_IRUSR` | bit 0 (read-enable) |
| `S_IWUSR` | bit 1 (write-enable) |
| unlink/rename gating | bits 7/6 (destroy-, rename-enable) — no POSIX analogue; keep them coupled to `S_IWUSR` |
| `S_IXUSR` | **no ProDOS home** — synthesize from the FGX header magic, or report 0 until UFS |
| group/other, setuid/setgid/sticky | **no ProDOS home** — stored only on UFS |

That asymmetry is the honest limit of this phase: on ProDOS, `chmod` can move
two bits and `chown` cannot do anything at all. `chown` therefore lands with
UFS, not here.

`umask` needs a per-process word (u-area, `U_Cmask`, +2 B) and a shell builtin —
`bsh` already has `SYSUMASK` compiled in, `jsh` needs one; `/etc/profile:41-43`
documents exactly why the `umask 022` line is commented out today.

### 2.6 Enforcement comes last

Deliberately **P6, behind UFS**. Adding checks before there are real on-disk
modes to check against means enforcing synthesized permissions — the failure
mode is a system that denies operations for reasons no file records. The
chokepoints, when it is time: `Fs_Open`/`Fs_Create`/`Fs_Unlink`/`Fs_Rename`
(mode + owner), `Load_Binary` (exec bit), `_Sys_Kill` and the signal fan-out
(`signal.s:119-140` — same-uid-or-root), and `_Sys_SetPgid`. All of them call
`_Suser` (§2.2) rather than open-coding.

---

## 3. Phases & gates

Every phase is suite-green and revertible. P0–P4 are all doable on ProDOS today
and are what make telnetd safe to expose; P5–P6 are where UFS becomes the gate.

- **P0 — close the seam + numbering (~0.5).** ✅ **COMPLETE 2026-07-28.**
  *Numbering:* getuid→24, getgid→47, 21/22 reserved, `EQU`s added to
  `include/loader.s`, doc table regenerated (`tools/gen_syscall_table.py`;
  `build.sh` gates on it); all 102 dispatch entries verified still at their
  labelled index. *Seam:* libc `getuid`/`getgid` now issue the real syscalls,
  `geteuid`/`getegid` delegate, and all four are declared in `unistd.h` /
  `stdlib.h` (dropped from the "not provided" list). **Gate met:**
  `tools/mame_test/tests/uidprobe.json` — `uidprobe: PASS uid=0 gid=0`, with
  the plan's poke check done by hand: temporarily returning sentinels from
  `_Sys_GetUid`/`_Sys_GetGid` produced `uid=55 gid=66` in userland, proving the
  values cross the boundary rather than libc still folding a constant; poke
  reverted. Toolchain suite 529/529 after a goldens REGEN (the pile grew by two
  functions, so every `.expected.bin` shifted — **zero `.expected.s` changed**,
  i.e. no codegen drift).
- **P1 — u-area credentials (~1).** ✅ **COMPLETE 2026-07-28.** Six fields
  (`U_SIZE` 30 → 42), globals deleted, inheritance wired into both `_ps_common`
  (spawn/fork) and `_vf_common` (vfork), `execve` verified to leave credentials
  alone (it never re-allocates the u-area).

  **Correction to §2.1 as written:** the u-area was *dead infrastructure* —
  allocated, zeroed and freed per task, but **no field had ever been
  dereferenced**; `_u` ($A8) was never written and `[_u],Y` appeared only in a
  comment. The Phase-3 design intended swtch to maintain `_u`, and that
  dispatcher refactor was deliberately deferred. So P1 does **not** use a
  maintained `_u`: the helpers (`_Uarea_Cur`/`_Uarea_FromTCB`, task.s) load it
  **on demand** from `SE_UareaPtr`. Hot path untouched, no shared-scratch
  aliasing (nothing else in the tree touches `$A8`), and `_u` is valid only
  immediately after a helper returns C=1 — documented at both sites.

  **Gate — and a flaw in this plan's own ordering.** The gate written here ("a
  parent sets a uid, forks, and both report it") **requires `setuid`, which is
  P2**; at P1 there is no way to establish a non-root parent. Substituted the
  P0 sentinel method: seeding init's `U_Ruid`/`U_Rgid` with 55/66 made
  `uidprobe` print `uid=55 gid=66` — which proves the u-area read path (the
  no-u-area fallback returns 0, so 55 cannot come from it) **and two
  generations of inheritance**, init → sh → uidprobe. Sentinel reverted;
  `uidprobe` green again at 0/0. `U_CREDS_LEN` confirmed = 12 from the kernel
  listing, so the 12-byte copy covers all six fields (a short copy would still
  have propagated the two seeded ones). **P2 upgrades `uidprobe` into a real
  inheritance gate for free.**
- **P2 — `set*id` (~0.5).** ✅ **COMPLETE 2026-07-28.** Four calls at 23/25/26/27
  + `_Suser`, POSIX rule (root moves all three; non-root moves only effective,
  only to real or saved-set). `EPERM` added to errno.s — it did not exist.
  `SYS_GETUID`/`SYS_GETGID` now return **real in A and effective in Y**, which
  is what V7/2.11BSD's getuid(2) does (r0/r1); that is why no `SYS_GETEUID`
  number exists, and it retires libc's `geteuid → getuid` delegation, which was
  only correct while the two could never differ. U-area fields were reordered
  into uniform {real,effective,saved} triples so setuid/setgid share one
  routine.

  **Gate met — and it has teeth:** `credprobe` walks the whole rule and ends by
  forking, requiring the child to report the same non-root ids. That last step
  **is P1's inheritance gate**, now reachable from userland because setuid can
  establish a non-root parent — the sentinel poke is retired. Mutation-tested:
  removing the `EPERM` path made it fail `regain-allowed (got 0, want -1)`,
  confirming the refusal is enforced rather than assumed.

  **This phase did not fit.** It overran the kernel-code ceiling by 101 B; see
  the reclamation note below.
- **P3 — passwd database (~1).** §2.3: real `getpw*`/`getgr*` in libc,
  `disk_src/etc/passwd` + `/etc/group`, extended `struct passwd`. **Gate:** a
  fixture resolving root by name and by uid, and a miss returning NULL. This
  also clears the `pwd.h` link hazard.
- **P4 — `login`/`id` + init handoff (~0.5–1).** §2.4, plus `ls` dropping its
  hardcoded names. **Gate:** boot to a shell whose environment came from the
  passwd file (`USER`/`LOGNAME` set, `HOME` from `pw_dir`); `id` prints
  `uid=0(root) gid=0(fgx)`; `ls -l` shows the same names via lookup, and a
  numeric fallback for an unknown uid. Suite green.
- **P5 — mode bits + `chmod`/`umask` (~1).** §2.5. **Gate:** `chmod -w` on a
  ProDOS file, `stat` reflects the cleared `S_IWUSR`, `chmod +w` restores it;
  `umask` round-trips through the shell builtin. Suite green.
- **P6 — enforcement (deferred, behind UFS).** §2.6. Not costed here; it wants
  UFS's real on-disk modes underneath it and is the one phase that can break a
  working system.

## 4. Test plan

- **`getuid_syscall.json`** (P0) — the value crosses kernel→userland.
- **`cred_fork.json`** (P1) — inheritance across `fork` and `vfork`.
- **`setuid_rules.json`** (P2) — the three permission outcomes.
- **`passwd_lookup.json`** (P3) — name/uid hit, and a miss.
- **`login_env.json`** (P4) — environment sourced from `/etc/passwd`; `id` and
  `ls -l` output byte-checked.
- **`chmod_prodos.json`** (P5) — write-bit round-trip through the ProDOS access
  byte.
- Regression: full suite after each phase. P1 touches fork/spawn (hot path) and
  P5 touches `stat`, so both want the whole suite, not a subset.

## 5. Risks & coordination

1. ~~**The 21/22 collision is a now-or-never call.**~~ **Closed 2026-07-28** —
   renumbered while it was still free (nothing called those slots). Had it
   waited until libc was wired, it would have been a libc + kernel + doc change
   with a compatibility story. One lesson worth keeping: `userland-abi.md`'s
   syscall table is **generated** from `include/loader.s`, and `build.sh` fails
   the build on drift — hand-editing the table is always wrong, and an *indented*
   comment in loader.s is swept into the preceding `EQU`'s description (use a
   column-0 comment for anything that isn't a syscall's own docs).
2. **U-area growth touches the swtch path.** `SE_UareaPtr` is swapped per task
   (`include/kernel.s:459`); a larger u-area is a larger Kmalloc per task, which
   the preemption campaign's kernel-heap work also touches. Sync with that owner
   before P1 — same caution the UFS plan raises.
3. **`vfork`'s snapshot restore is subtle.** The child performs the restore and
   the scheduler never reads `SE_SnapPtr` (`include/kernel.s:478-484`);
   credentials must be captured at snapshot time. Getting this backwards yields
   a child that inherits the *post*-setuid credentials of a parent that hadn't
   set them yet.
4. **Nothing consumes setuid images.** P2 gives `setuid(2)`, but exec does not
   honor an `S_ISUID` bit — there is nowhere to store one on ProDOS (§2.5) and
   `Load_Binary` gates on header magic, not mode (`loader.s:192-202`). So
   privilege *elevation* does not exist until UFS. This is a feature for now:
   `login` drops privilege, nothing regains it.
5. **Task-slot recycle zeroes to root** (§2.1). Safe while init is the only
   unparented spawner; a network daemon that forks is exactly the case that
   breaks it — coordinate with telnetd P3.
6. **Enforcement is the sharp edge.** Landing P6 early, on synthesized ProDOS
   permissions, risks denying operations no on-disk record justifies. Its
   position behind UFS is deliberate, not scheduling convenience.
7. **The stat layout is mid-migration.** `_Sys_Stat` returns the legacy 15-byte
   buffer and libc translates (`libc_c.c:1462-1495`); the `STX_*` struct with
   `STX_uid`/`STX_gid` is dead code (`include/fs.s:576-590`). When UFS carries
   real ids, that dead struct is the intended destination and libc `stat()` is
   the seam that stops zeroing them. Owned by the UFS campaign, cited here so
   neither plan assumes the other did it.

## 6. Out of scope (follow-ons)

Supplementary groups (`getgroups`/`setgroups`/`u_groups[]`); password hashing
(`crypt(3)`) and `passwd(1)` — they arrive with telnetd's authentication
follow-on, which the telnetd plan `:170` also defers; `su(1)`; utmp/wtmp
accounting and `who`/`last` (the headers exist, `toolchain/include/utmp.h`, but
single-console FGX has no sessions to account for until telnetd multiplexes);
`getty`; `chown`/`chgrp` (no ProDOS home — UFS); file ACLs; per-user quotas;
`S_ISUID` exec elevation (§5.4); and enforcement itself (P6, costed with UFS).

## 7. Open decisions for the maintainer

1. ~~**The 21/22 numbering.**~~ ✅ **DECIDED 2026-07-28 — option (a), landed.**
   getuid→24, getgid→47; 21/22 reserved for UFS's `mount`/`umount`. Follow-on
   for §2.2: `setuid` takes BSD's 23, `setgid` goes FGX-local at 25 (BSD's 46 is
   spent on `SYS_VFORK`) — confirm at P2 if you'd rather they sit elsewhere.
2. **Does `init` exec `login(1)`, or perform the passwd lookup inline?** Inline
   is recommended for v1 (keeps the boot path single-process, no getty layer);
   exec'ing `login` is more BSD-shaped and is what telnetd would eventually want
   per-session.
3. **Is P5 (mode bits + `chmod`/`umask`) in this campaign, or does it ride with
   UFS?** It is genuinely useful on ProDOS — the write-enable bit is already
   live — but it is also the phase whose value roughly doubles once UFS lands.
4. **Password field for v1** — `*` (no password, no prompt, recommended), or
   land a minimal `crypt(3)` now so telnetd inherits a working auth story rather
   than deferring it twice?

Cross-refs: the UFS second FST (`2026-07-21-unix-fs-second-fst-plan.md` §3.2
`mount(2)` numbering, `:119` inode uid/gid/mode, `:215` the real-stat promise) —
this plan is a prerequisite for its stat half; telnetd
(`2026-07-24-telnetd-plan.md:68,170`, which scopes login and auth out on the
grounds this layer is missing); the preemption campaign
(`2026-07-17-preemption-campaign-roadmap.md`, kernel-heap/u-area overlap).
Suggested ledger: a new **userland / process model** campaign.
