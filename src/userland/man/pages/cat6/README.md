# Games manual pages (cat6)

Unlike the `cat1`..`cat5`/`cat8` pages in this tree, which are pre-formatted
**2.11BSD** cat pages carrying the Regents of the University of California
copyright, `cat6/frotz.0` is an **original** page written for FGX's frotz port.
It documents behaviour specific to that port (the full-screen SHR interface,
the bank-spanning story memory, the option set frotz(6) actually accepts), so
there is no upstream page to vendor.

frotz itself is GPL-2.0-or-later (see `src/userland/frotz/` and
`docs/PROVENANCE.md`); this page is documentation for it and is offered under
the same terms.

Format and build are identical to the other sections: nroff "cat" output with
teletype overstrike for emphasis (`_\bX` underline, `X\bX` bold), converted to
the console's SGR form by `tools/man_preformat.py` and staged to
`/usr/man/cat6/frotz.6`.  The build globs `cat[1-8]/`, so this directory needed
no code change.
