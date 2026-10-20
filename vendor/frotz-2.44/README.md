# vendor/frotz-2.44 — Frotz 2.44 (pristine subset)

Stefan Jokisch's Frotz, the portable Z-machine interpreter, at the 2.44
Unix release (Galen Hazelwood / David Griffith maintenance line).  Licence:
**GPL-2.0-or-later** (`COPYING`).

Fetched 2026-09-19 from
<https://ifarchive.org/if-archive/infocom/interpreters/frotz/old/frotz-2.44.tar.gz>
(sha256 `73ec20f034d2e91578c387cff3af249d52b8833e4271eb1053f6d335722fe3ec` over the full tarball).

Vendored subset: `src/common/` (the Z-machine core), `src/dumb/` (the
dumb/stdio interface FGX ports), and the top-level docs.  The curses, DOS,
SDL and blorb interfaces are not vendored — FGX builds none of them.

The FGX port lives at `src/userland/frotz/`; per the ports convention this
tree stays pristine for diffing.
