# Versioning

The toolchain carries no version of its own: `fcc`, `fas`, `fgx_ld` and `lib/`
are versioned, tagged and released with the OS under
**[../../docs/VERSIONING.md](../../docs/VERSIONING.md)**.

A change to language acceptance, the ABI, the syscall contract, or the
emitted-code contract is a **breaking** change and takes the `!` marker (see
[CONTRIBUTING.md](CONTRIBUTING.md)); it drives FGX's SemVer bump.

`git describe --tags --match 'v*'` supplies `fcc --version` provenance, so local
`checkpoint/...` / `wip/...` tags never leak into it.
