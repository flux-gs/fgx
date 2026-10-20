# Versioning Policy

FGX ships as **one unit** — kernel, boot loader, userland, the C toolchain, and
the on-disk image build and gate together — so it carries a single
`vMAJOR.MINOR.PATCH`.

Since the monorepo merge this is literal: `fcc` is in-tree at `toolchain/` and
no longer carries a version of its own. A change spanning compiler and OS is one
commit, one tag.

## What a bump means

| Bump  | Means                                                                          |
|-------|--------------------------------------------------------------------------------|
| MAJOR | breaking change to the syscall ABI, on-disk layout, kernel↔module contract, or boot/userland compatibility — existing binaries/disks may not work unchanged |
| MINOR | new backward-compatible capability (new syscall, tool, filesystem feature, driver)    |
| PATCH | bugfix, no ABI- or format-visible change to already-working binaries/disks     |

## Tag namespaces — two lifecycles

- **Release tags `vX.Y.Z`** — annotated and **pushed**. Invariant: a `v*` tag
  may only sit on a commit with a green `tools/gate.sh` receipt (see
  [RELEASING.md](RELEASING.md)). The annotation records the gate result and
  whether the syscall/ABI or on-disk layout changed vs the prior tag.
- **Checkpoint tags** — local rollback scaffolding, **never pushed**, pruned
  periodically. Going forward use `checkpoint/…` or `wip/…`. The large body of
  historical `pre-*` / `post-*` / `ckpt/*` / `wip/*` tags are
  grandfathered as checkpoints — leave them, don't push them.

## Version provenance

The on-disk/boot version string is derived at build time via
`git describe --tags --match 'v*' --always` plus a `+` when the tree is dirty
(see `tools/make_ufsboot.sh`, which writes `/etc/version` and `/etc/build`). The
`--match 'v*'` is load-bearing: it keeps the checkpoint tags out of the version
string. Yields `vX.Y.Z` on a tag and `vX.Y.Z-N-gSHA` after it, with `+` when the tree
is dirty.

## Toolchain

The toolchain (`toolchain/`: fcc, fas, fgx_ld, the C library) is versioned and
released with FGX; it has no version of its own.  Its tags from before the
merge live in the archived `apple/fcc` repository.
