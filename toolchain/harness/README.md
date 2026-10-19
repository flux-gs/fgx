# C90 torture harness (stub)

The GCC c-torture harness lands here in a follow-on spec: a headless GS-CPU
emulator + a test syscall layer (its own SYS_TRAMP → emulator trap, satisfying
../lib/syscall.h) + a curated set of complex-C90 tests (from an external
`fcc-testsuite` corpus, not vendored in this repo), scored against a host-gcc
oracle. Empty until then.
