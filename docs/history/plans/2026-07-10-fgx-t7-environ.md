# T7-environ — finish the half-built environment pipeline (2026-07-10)

Redesign §T7 first item.  Survey verdict: the ABI already exists end to
end — `SYS_POSIX_SPAWN` takes envp in Y (NULL-terminated table of
caller-bank string offsets; 0 = empty), the loader measures/stages the
BSD argv/envp frame onto the child's stack (`_la_envpPtr`,
`_Loader_MeasureArgs`), and crt0's frame comment documents
`5+2*argc,S envp[0]`.  What's missing is everything *around* it:

- crt0 walks argv only — envp is never captured into the child.
- libc `c_getenv` is the **"vt100" booby trap**: any name starting 'T'
  returns a baked "vt100", everything else NULL.
- jsh has a real env store (`env_buf`, 'E'/'L' export markers, `export`
  builtin) but spawns via 2-arg `spawn`/`spawnx` — exported vars never
  leave the shell.
- Nothing seeds TERM/PATH/HOME at boot.

## Increments

- **E1 — capture + getenv.**  `toolchain/lib/args.s` gains `args_env`
  (packed `NAME=VAL\0...\0\0` block, fail-soft truncate like
  args_input) + `args_envc`.  Both crt0s (FGX `src/userland/lib/
  crt0_c.s` for real tools, `toolchain/lib/crt0_far.s` for fixtures)
  copy the kernel-laid envp strings after the argv walk.  `c_getenv`
  rewritten: walk args_env in the caller's data bank, match up to '=',
  return a pointer past it (bank = DBR); booby trap RETIRED.
  setenv/putenv stay unbound (fail-loud; no consumer — jsh mutates its
  own table, ports get them at T5-C).
- **E2 — spawnve + jsh export passing.**  New shim `c_spawnve(path,
  argv, envp)` (Y = envp table, same int-offset shape jsh already
  builds for argv); binding `spawnve`.  jsh: build the envp table from
  env_buf's 'E' entries at spawn; seed env_buf from jsh's OWN inherited
  environment at startup (nested shells inherit).  KNOWN GAP: SPAWNX
  (file_actions redirects) has no envp register — redirected spawns
  lose the env for now (documented; the register set is full).
- **E2b — system()/popen() forward the caller's env** (libc builds an
  offset table from args_env into libc_data scratch) — the spawn-only
  world's answer to fork's implicit inheritance.
- **E3 — /etc/profile + TERM.**  Disk ships `/etc/profile`
  (`export TERM=vt100`, PATH, HOME — vt100 keeps the name the baked
  termcap answered with); jsh sources it at interactive startup.
- **Proof**: `envtest` userland tool (getenv round-trip) + a mame_test
  JSON driving `export FOO=...; envtest` through jsh; elvis smoke:
  curses.c's `getenv("TERM")` now reads the real environment.

## Execution status (2026-07-10 — ★COMPLETE, unreleased)

- **[x] E1** (tc d7d42857 / FGX 6c9c98c8): args_env + args_envc storage;
  both crt0s capture; c_getenv real walk; booby trap retired.
- **[x] E2** (same commits): c_spawnve + binding; jsh spawnve stub +
  exported-vars table + env_import (nested inheritance); SPAWNX gap
  documented.
- **[x] E3** (FGX 6c9c98c8): /etc/profile (`export TERM=vt100`) +
  jsh sources it at interactive startup; envtest tool + tests JSON.
- **[x] E2b** (tc, follow-up commit): system()/spawnv() forward the
  caller's env via _libc_build_envp — in the SHIMS pile (hand-asm
  tools PUTting libc.s alone must assemble; sigtest).
- **PROOF**: envtest rc=42 on MAME (profile TERM + jsh-exported var +
  NULL for unset — the kernel's Slice-3 envp staging exercised for the
  first time and it WORKED); fast group 21/21 (every jsh command now
  spawns via spawnve); toolchain goldens 394/394 + differential green.
- Gotchas recorded: EQUs don't cross segment assemblies (ARGS_ENV_MAX
  duplicated per unit like the templates' ARGS_*); test tools need BOTH
  build_userbin_fgx2_c registration AND the disk_src/testbin cp line.

## Branches

toolchain `feat/t7-environ` off `feat/fcc-correctness-queue`;
FGX `feat/t7-environ` off `feat/t22-pp-token-pass`.  No release until
The maintainer's train (stacks beneath).
