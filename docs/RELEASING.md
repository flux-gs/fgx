# Releasing FGX

A release is a `vX.Y.Z` tag on a fully gate-backed commit on `main`.

> **One command:** `./release.sh` previews (suggested bump + the unreleased
> commits, does nothing); `./release.sh vX.Y.Z` (or `--auto`) runs the whole loop
> below — gate receipt, changelog, `chore(release)` commit, parked on
> `release/vX.Y.Z` and pushed with a pull request opened. `main` changes only
> through pull requests, so pushing the tag is a **second** step once the pull
> request merges: `./release.sh --tag vX.Y.Z`.
> `--merge feat/x` lands a branch first. The numbered steps below are exactly
> what it does (and the reference for doing any of it by hand).
>
> `fcc` lives in-tree at `toolchain/` and is released with everything else.

1. **Land commits** following [CONTRIBUTING.md](CONTRIBUTING.md): an
   `area: statement` subject and an informational body, which becomes the
   changelog entry.
2. **Run the gate** — `tools/gate.sh`. It builds (`ninja all`), runs fcc's
   fixtures if `toolchain/` changed, runs the gate's MAME tests, and writes a receipt to
   `.gate/<sha>.json`.
   - `release.sh` does **not** run the gate; it READS that receipt and requires
     `mode: smoke`, `ok: true`, and a matching tree. A **missing** receipt is
     treated exactly like a red one, and a `build-only` receipt is refused
     because it does not attest that the OS boots.
   - **Live-network behaviour** (`dhclient`, `ping`) is no longer gated at all;
     verify it by hand when networking changed.
3. **Pick the bump** from the landed commits (see [VERSIONING.md](VERSIONING.md)).
   Read the commit bodies for ABI and layout changes.  `git-cliff
   --bumped-version` (what `--auto` uses) sees only Conventional Commits types
   and `!`, and counts an `area:` commit as a patch, so its suggestion can be
   low.
4. **Generate the changelog** — **delta-prepend, never full regen**:
   `git-cliff --unreleased --tag vX.Y.Z --prepend CHANGELOG.md`, then commit it
   as `chore(release): vX.Y.Z`.
   - `--unreleased` emits only commits since the last `v*` tag; `--prepend`
     inserts that one section at the top and leaves released entries frozen.
   - **Each entry is the commit subject plus its whole body**, indented under
     it, with the attribution trailers removed (`cliff.toml`).  An `area:`
     commit is listed under "Changed" with its full subject; older Conventional
     Commits sort by type.  Merge and `wip` commits are left out.  A commit with
     no body shows its subject alone.  See [CONTRIBUTING.md](CONTRIBUTING.md).
   - Do **not** use `git-cliff --tag … -o CHANGELOG.md` (full regen) for normal
     releases: it re-derives every prior section from the entire history and
     rewrites frozen changelogs. (The `v0.1.0` baseline was a one-time full regen
     to seed the file; every release after it uses the delta form.)
5. **Tag** — annotated (`git tag -a`), recording the gate result and whether the
   syscall/ABI or on-disk layout changed vs the prior tag:
   `git tag -a vX.Y.Z -m "vX.Y.Z — gate: build OK + smoke test green; abi/layout: <changed|unchanged> vs <prev>"`.
6. **Publish through a pull request** -- `main` changes only through pull
   requests, so the release lands as a two-step: `release.sh` parks the
   release commits on `release/vX.Y.Z` (the changelog, and the README's
   download link moved to the new version), pushes that branch, and opens the
   pull request.  Merge it with a **merge commit**, not a squash or rebase:
   the tag is made on the release commit, and only a merge commit puts that
   commit on `main`.  Then run `./release.sh --tag vX.Y.Z` to push the tag.

## The published image

Pushing a `vX.Y.Z` tag runs `.github/workflows/build.yml`.  It builds the
toolchain, runs fcc's fixture and library suites, builds `disk/fgxroot.fs` with
`ninja release` on Linux, and publishes it on the tag's GitHub release as
`fgx-X.Y.Z.fs`; the version is in the file name and in the image as
`/etc/version`.  A maintainer can also start the build by hand from the
Actions tab.

Every push to `main` runs the same build and publishes its image on the
rolling `main-latest` pre-release as `fgx-main-<commit>.fs`, moving the
`main-latest` tag to that commit and deleting all but the newest three
(`MAIN_KEEP` in the workflow).  Release assets are stored outside git, so
neither these nor the release images grow the repository.  A pre-release is
never GitHub's "Latest", so the newest `vX.Y.Z` stays the default download.
`/etc/version` in a `main` image is `git describe`'s, e.g.
`v2.0.0-5-g712de08`.

Pull requests and other branches do not start the build, and it does not
attest that a commit boots: the gate (`tools/gate.sh`, run locally, since the
MAME tests need a ROM) does that.  merlin32 is built from upstream
plus `.github/merlin32-cr-lookback.patch`, and cadius at a pinned commit; the
pins are in the workflow.

## Toolchain

`fcc` is in-tree at `toolchain/` and released with FGX: a change that spans the
compiler and the OS is one commit, one branch, one pull request, one gate.

## Checkpoint tags (local scaffolding)

Personal rollback points use `checkpoint/…` or `wip/…`, stay local, and are
never pushed. `git describe --match 'v*'` keeps them out of the version string.
