# The 2.11BSD Bourne /bin/sh port

The source is `vendor/2.11BSD/usr/bin/sh`, built by the manifest (`sh` in
`tools/ninja/manifest.json`; its other TUs are listed in `tu.list` here).  It
links statically (fgx_static) against libc's library-mode compile and libfgx's
program-mode compile: sh is the console shell and the recovery shell when
libc.so will not load, so it needs no shared library.

sh defines its own malloc, free, rename and setenv, as 2.11BSD's does;
fgx_static's archive-search rule (fgx_gc.graph) makes them THE definitions,
and libc's own callers bind to them.

FGX-specific overrides of `<...>` system headers go in this directory (an
`-I` dir ahead of `toolchain/include`), the same discipline as
`src/userland/tcsh/`.  `src/softscc/sh.txt` lists the functions whose frames
fcc moves to the soft stack.

## Edits to the vendored source

Grep the vendored tree for "FGX" to find each one; keep this list in step.

1. `service.c`: gocsh's `newt[1000]` is `static`.  1000 far pointers is
   4,000 B of bank-0 hardware stack, and bank 0 has a single arena shared by
   every live task, so the always-resident login shell held 16 pages of
   everyone else's spawn budget for a frame execve destroys.
2. `setbrk.c` + `stak.c` (apple/fgx#13): declare `char *sbrk();` and react to
   a refused break.  fault.c already carries `IF setbrk(brkincr) == -1 THEN
   error(nospace); FI`, but upstream reaches it from the MEMF write-fault
   signal, which FGX cannot deliver, so the proactive locstak call is the
   only site that learns; the same test and error() go there.  Undeclared,
   K&R makes sbrk int-returning and the break's bank was lost.
3. `word.c` + `blok.c` (apple/fgx#16): the lexer and addblok grow the break
   BEFORE writing, for the same reason: there is no MEMF fault to grow it.
4. `stak.h` + `stak.c` (pushstak, getstak, cpystak), `name.c`, `service.c`,
   `expand.c`, `io.c`, and `word.c` counting per word: the same rule for
   every other stak writer.  pushstak checks its room inline (stakroom) and
   each bounded copy reserves its length first (stakneed), so nothing the
   shell holds lies past the break.
