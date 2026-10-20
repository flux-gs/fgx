# Releasing

The toolchain is not released separately: `fcc`, `fas`, `fgx_ld` and `lib/` ship
with the OS in one release, cut from the repo root with `./release.sh`. See
**[../../docs/RELEASING.md](../../docs/RELEASING.md)**.

The gate is FGX's `tools/gate.sh`. It runs fcc's fixture suite only when the content
hash of the tracked sources under `toolchain/` (and `src/kernel/vfs`, whose
headers a fixture includes) differs from the one recorded when the fixtures last
passed (`fcc_source_hash` in `tools/gate.sh`). To run the fixtures directly: `bash toolchain/tests/run.sh`
(`REGEN=1` rewrites the goldens).

Commit conventions: [CONTRIBUTING.md](CONTRIBUTING.md).
