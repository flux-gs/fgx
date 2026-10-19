# Contributing -- Commit Conventions

The toolchain is part of the FGX monorepo and follows FGX's
[Conventional Commits](https://www.conventionalcommits.org) rules in
[../../docs/CONTRIBUTING.md](../../docs/CONTRIBUTING.md). The root `cliff.toml`
turns them into FGX's `CHANGELOG.md` and SemVer bump at release (see
[VERSIONING.md](VERSIONING.md)).

## Format

```
type(scope): imperative subject   # <= 72 chars
```

Optional body (wrapped) and footers follow a blank line.

## Types

`feat` `fix` `perf` `refactor` `docs` `test` `build` `chore` `revert`

## Scopes (toolchain modules)

`fcc` `as` `ld` `lib` `crt0` `libc` `include` `tests` `syscall` `abi` `docs`
(`fcc` is the compiler, `as` the assembler). The scope is a hint, not a gate.

## Breaking changes -- the `!` marker

Mark a breaking change with `!` after the type/scope, or a `BREAKING CHANGE:`
footer:

```
feat(fcc)!: change long-long ABI to ORCA layout
```

The `!` marker does double duty:

1. **SemVer signal** -- it drives FGX's version bump (see VERSIONING.md).
2. **Golden signal** -- it tells the reader that the fcc goldens change
   intentionally and are regenerated in the same commit
   (`REGEN=1 bash toolchain/tests/run.sh`), not treated as a regression.

Use `!` for any change to language acceptance, the ABI, the syscall contract,
or the emitted-code contract.
