# Manual pages (cat1-cat8)

The `cat<N>/*.0` files in this directory are pre-formatted ("cat") manual
pages: nroff *cat* output, plain text with teletype overstrike for emphasis
(`X\bX` = bold, `_\bX` = underline).  There is no nroff source for them in the
tree, so the `.0` file IS the page: edit it directly and keep the overstrike,
the column layout and the header/footer lines intact.  FGX has no on-device
nroff/troff; like 2.11BSD's own `man(1)`, our [`man`](../man.c) is a cat-page
*locator*, so these are the pages it shows.

Two kinds of page live here:

- **Vendored 2.11BSD pages** from `vendor/2.11BSD/usr/man/cat<N>/` or the full
  distribution under `examples/2.11BSD/usr/man/`.  They keep 2.11BSD's
  `Printed 11/26/99` page footers.  Where the FGX port differs from upstream,
  the difference is stated in the page's BUGS section.
- **Pages written for FGX**, for FGX-native tools and for ports whose behaviour
  differs enough that the upstream page would mislead (for example
  `cat6/frotz.0`, see `cat6/README.md`).  `tools/check_man_overstrike.py`
  checks that these spell emphasis as overstrike rather than literal
  underscores; it runs in the build's checker stage (`tools/ninja/gen.py`).

## How they reach the disk

The `man pages` block in `tools/ninja/gen.py` globs `cat[1-8]/*.0` and runs
`tools/man_preformat.py` on each section.  It rewrites each page into the form
the FGX SHR console renders -- overstrike to SGR (distinct bold `ESC[1m` /
underline `ESC[4m`), tabs expanded to 8-column stops, lines left LF-terminated
(the tty's ONLCR supplies the CR) -- and writes it to
`disk_src/usr/man/cat<N>/<name>.<N>`, lowercase (`grep.0` becomes
`/usr/man/cat1/grep.1`), because man(1) does not case-fold.  The converted
pages are build output and gitignored; only the `.0` sources here are tracked.

`vendor/2.11BSD/` is committed (see `vendor/README.md`).  The pages are copied
here rather than read from it because the shipped set is curated: it holds a
page for each tool FGX ships (plus a few shell builtins users expect to `man`),
not the whole upstream `usr/man`, and it carries FGX-specific pages and BUGS
text that upstream does not have.

## Adding a page

Drop its `.0` into `cat<N>/`.  A new section is just a new `cat<N>/`
directory (its pages stage to `/usr/man/cat<N>/` with a `.<N>` suffix); no
code change is needed.

Some staged tools have no page yet: `arch`, `dirname`, `hd`, `modload`,
`mount`, `umount`, `robots`, `worm`, `netdump` and `tput`.

## Provenance / license

The vendored pages are Copyright (c) Regents of the University of California,
part of 2.11BSD, redistributed under the BSD license (see the repository
`LICENSE` and `docs/PROVENANCE.md`).  They are reference documentation, not
source compiled into FGX; UCB attribution is retained here and in
`docs/PROVENANCE.md`.
