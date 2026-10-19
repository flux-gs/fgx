CC     ?= cc
CFLAGS ?= -O -Wall

# Version provenance: describe relative to RELEASE tags (v*) ONLY, so the local
# checkpoint tags (pre-*/post-*) never leak into the version string.  Yields a
# short SHA before v0.1.0, "v0.1.0" on the tag, "v0.1.0-N-gSHA[-dirty]" after,
# and "unknown" outside a git tree.
FCC_VERSION := $(shell git describe --tags --match 'v*' --always --dirty 2>/dev/null || echo unknown)

CC_SRCS := $(wildcard src/cc/*.c)

.PHONY: all clean test test-peephole test-lex test-libs hooks
all: hooks fcc fas piles

# Enable the repo's git hooks (the pre-push guard) on build -- core.hooksPath is
# local config, not cloned. Idempotent; never fails the build.
hooks:
	@git rev-parse --git-dir >/dev/null 2>&1 && [ -d tools/hooks ] && [ -z "$$(git config --local core.hooksPath 2>/dev/null)" ] && git config core.hooksPath tools/hooks && echo "enabled git pre-push guard (core.hooksPath=tools/hooks)" || true

fcc: $(CC_SRCS) $(wildcard src/cc/*.h)
	$(CC) $(CFLAGS) -DFCC_VERSION='"$(FCC_VERSION)"' -o $@ $(CC_SRCS)

fas: src/as/fas.c
	$(CC) $(CFLAGS) -o $@ src/as/fas.c

# T5-C: the C-converted pile TUs.  They are BUILD OUTPUTS, not tracked
# (apple/fgx#385): `make' (all) writes them, and the OS build refuses a stale
# one through tools/check_libc_piles.py.
# WHY THESE ARE FILE TARGETS, NOT PHONY (changed 2026-07-26):
# they used to read `libc_c: fcc`, i.e. PHONY with no file prerequisites and NOT
# in `all`.  Plain `make` therefore never regenerated them, so editing
# lib/libc_c/libc_c.c and running `make` silently assembled against the OLD
# checked-in pile.  That trap invalidated an entire day of bisection: several
# functions were "exonerated" against a pile that never contained them.  With
# real prerequisites, `make` cannot test a stale pile.
#
# GNU make 3.81 has no grouped-target syntax, so each rule names its PRIMARY
# product and the _data.s sibling simply depends on it -- the one recipe writes
# both.

# The prerequisite set MUST mirror ARTIFACTS['libc_c'] in
# ../tools/check_libc_piles.py.  If the guard watched a header this rule does
# not, a change to it would fail the build while `make libc_c` reported nothing
# to do -- an unbreakable deadlock.  arpa/ and netinet/ were missing here until
# 2026-07-31.  fcc's OWN sources are watched too (apple/fgx#33) and reach this
# rule through its `fcc` prerequisite, so the subset rule still holds.
lib/libc_c.s: $(wildcard lib/libc_c/*.c) $(wildcard include/*.h) $(wildcard include/sys/*.h) $(wildcard include/arpa/*.h) $(wildcard include/netinet/*.h) fcc
	./fcc --pile lib/libc_c/libc_c.c -o lib/libc_c.s --data-segment lib/libc_c_data.s
	python3 ../tools/check_libc_piles.py --write libc_c
lib/libc_c_data.s: lib/libc_c.s
libc_c: lib/libc_c.s

# libc in library mode (shared libc SP2): the same members, compiled for
# libc.so -- calls by JSL, literals in code, each member's statics in a
# block (lib/libc_so.blocks.json), core.list's statics in the core.
# FGX_AR_HAVE_fltpr: one libc serves every program, so its printf formats
# floating point (%e, %f, %g) for all of them, as SunOS 4.1.3's shared libc
# does.  A static link makes the fltused/ffltpr choice itself: fgx_static
# links lib/ffltpr.c over fltpr for a program with no fltused marker.
lib/libc_so.s: $(wildcard lib/libc_c/*.c) $(wildcard include/*.h) $(wildcard include/sys/*.h) $(wildcard include/arpa/*.h) $(wildcard include/netinet/*.h) lib/libc_c/core.list fcc
	./fcc --libso --sections -DFGX_AR_HAVE_fltpr --core-list lib/libc_c/core.list --emit-blocks lib/libc_so.blocks.json lib/libc_c/libc_c.c -o lib/libc_so.s --data-segment lib/libc_so_data.s
	python3 ../tools/check_libc_piles.py --write libc_so
lib/libc_so_data.s: lib/libc_so.s
lib/libc_so.blocks.json: lib/libc_so.s
# termlib and curses in library mode (shared libc SP3): each names its
# block cells after itself (--libso-name).
lib/libtermlib_so.s: $(wildcard lib/libtermlib_c/*.c) $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libtermlib --sections --emit-blocks lib/libtermlib_so.blocks.json -Ilib/libtermlib_c lib/libtermlib_c/libtermlib.c -o lib/libtermlib_so.s --data-segment lib/libtermlib_so_data.s
lib/libtermlib_so_data.s lib/libtermlib_so.blocks.json: lib/libtermlib_so.s
lib/libcurses_so.s: $(wildcard lib/libcurses_c/*.c) lib/libcurses_c/curses.ext lib/libcurses_c/core.list $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libcurses --sections -DNOSCCS --core-list lib/libcurses_c/core.list --emit-blocks lib/libcurses_so.blocks.json -Ilib/libcurses_c lib/libcurses_c/libcurses.c -o lib/libcurses_so.s --data-segment lib/libcurses_so_data.s
lib/libcurses_so_data.s lib/libcurses_so.blocks.json: lib/libcurses_so.s
# libc.so: the library-mode compile, packed into banks and linked with its
# core and block templates (src/ld/fgx_libso.py; lib/libc_so.d holds the
# segments, listings and fgx_ld manifest).
lib/libc.so.1.0: lib/libc_so.s lib/libc_so_data.s lib/libc.s lib/fcc_libc_shims.s \
		lib/fcc_runtime.s lib/libc_data.s lib/args_data.s lib/fcc_runtime_data.s \
		$(wildcard lib/libllong/*.s) lib/libdouble/d_stub.s lib/macros.s \
		src/ld/fgx_libso.py src/ld/fgx_ld.py src/ld/fgx_gc.py tools/gen_seg1_layout.py \
		lib/libc_so.blocks.json lib/libc_c/core.list lib/libc_c/data.exports \
		lib/libc_so_helpers.s lib/libc_start.s lib/libc_start_data.s lib/ld_bind_asm.s \
		lib/ld_bind_entry.s
	python3 src/ld/fgx_libso.py --out lib/libc.so.1.0 --dir lib/libc_so.d
libc_so: lib/libc_so.s lib/libc.so.1.0
# The shared libraries above libc -- libfgx, libtermlib, libcurses and
# libutil -- each linked against the ones below it (shared libc SP3 spec,
# section 2).
LIBSO_LD := src/ld/fgx_libso.py src/ld/fgx_ld.py src/ld/fgx_gc.py src/ld/fgx_imports.py src/ld/fgx_sites.py tools/gen_seg1_layout.py
lib/libtermlib.so.1.0: lib/libtermlib_so.s lib/libtermlib_so_data.s lib/libtermlib_so.blocks.json lib/libtermlib_helpers.s lib/libtermlib_helpers_data.s lib/libtermlib_c/data.exports lib/libc.so.1.0 lib/libfgx.so.1.0 $(LIBSO_LD)
	python3 src/ld/fgx_libso.py --lib libtermlib --out lib/libtermlib.so.1.0 --dir lib/libtermlib_so.d
lib/libcurses.so.1.0: lib/libcurses_so.s lib/libcurses_so_data.s lib/libcurses_so.blocks.json lib/libcurses_c/data.exports lib/libcurses_c/core.list lib/libc.so.1.0 lib/libtermlib.so.1.0 $(LIBSO_LD)
	python3 src/ld/fgx_libso.py --lib libcurses --out lib/libcurses.so.1.0 --dir lib/libcurses_so.d
# libfgx and libutil as shared libraries above libc (shared libc SP5).
lib/libfgx_so.s: $(wildcard lib/libfgx_c/*.c) $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libfgx --sections --emit-blocks lib/libfgx_so.blocks.json -Ilib/libfgx_c lib/libfgx_c/libfgx.c -o lib/libfgx_so.s --data-segment lib/libfgx_so_data.s
lib/libfgx_so_data.s lib/libfgx_so.blocks.json: lib/libfgx_so.s
lib/libutil_so.s: $(wildcard lib/libutil_c/*.c) $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libutil --sections --emit-blocks lib/libutil_so.blocks.json -Ilib/libutil_c lib/libutil_c/libutil.c -o lib/libutil_so.s --data-segment lib/libutil_so_data.s
lib/libutil_so_data.s lib/libutil_so.blocks.json: lib/libutil_so.s
lib/libfgx.so.1.0: lib/libfgx_so.s lib/libfgx_so_data.s lib/libfgx_so.blocks.json lib/libfgx_c/data.exports lib/libc.so.1.0 $(LIBSO_LD)
	python3 src/ld/fgx_libso.py --lib libfgx --out lib/libfgx.so.1.0 --dir lib/libfgx_so.d
lib/libutil.so.1.0: lib/libutil_so.s lib/libutil_so_data.s lib/libutil_so.blocks.json lib/libutil_c/data.exports lib/libc.so.1.0 lib/libcurses.so.1.0 $(LIBSO_LD)
	python3 src/ld/fgx_libso.py --lib libutil --out lib/libutil.so.1.0 --dir lib/libutil_so.d
libso_all: libc_so lib/libtermlib.so.1.0 lib/libcurses.so.1.0 lib/libfgx.so.1.0 lib/libutil.so.1.0

# BSD-foundations P1: the FGX platform-library pile (co-assembled into the
# shared LIBC segment after libc_c.s; see include/fgx.h).  A build output, like
# libc_c.s.
lib/libfgx.s: $(wildcard lib/libfgx_c/*.c) $(wildcard include/*.h) fcc
	./fcc --pile --sections lib/libfgx_c/libfgx.c -o lib/libfgx.s --data-segment lib/libfgx_data.s
	python3 ../tools/check_libc_piles.py --write libfgx
lib/libfgx_data.s: lib/libfgx.s
libfgx: lib/libfgx.s

# termcap library whole-pile.  No tool links this pile (they link
# libtermlib.so) -- but it is NOT dead: it is the termcap whole-graph
# STACK-CHECK AGGREGATE in tests/run.sh.  It defines UP, BC, PC and ospeed, as
# 2.11BSD's libtermlib does; a program's tentative definitions merge with them.
lib/libtermlib.s: $(wildcard lib/libtermlib_c/*.c) $(wildcard include/*.h) fcc
	./fcc --pile-far-extern lib/libtermlib_c/libtermlib.c -o lib/libtermlib.s --data-segment lib/libtermlib_data.s
	python3 ../tools/check_libc_piles.py --write libtermlib
lib/libtermlib_data.s: lib/libtermlib.s
libtermlib: lib/libtermlib.s

# curses library whole-pile (4.3BSD curses via 2.11BSD usr.lib/libcurses;
# textual aggregation of the members; -DNOSCCS dedups each member's sccsid[]).
# NO tool links this pile (they link libcurses.so) -- its sole job is the
# curses whole-graph STACK-CHECK AGGREGATE in tests/run.sh (walks the entire
# call graph; per-member checks would miss cross-member recursion depth).  Do
# NOT delete it as a "dead pile".
lib/libcurses.s: $(wildcard lib/libcurses_c/*.c) $(wildcard include/*.h) fcc
	./fcc --pile-far-extern -DNOSCCS lib/libcurses_c/libcurses.c -o lib/libcurses.s --data-segment lib/libcurses_data.s
	python3 ../tools/check_libc_piles.py --write libcurses
lib/libcurses_data.s: lib/libcurses.s
libcurses: lib/libcurses.s

piles: libc_c libc_so libfgx libtermlib libcurses lib/libdouble/softdouble.s

# The soft double (apple/fgx#447).  softdouble.s is fcc's own compile of
# lib/libdouble/softdouble.c (the llvm-mos soft double, docs/PROVENANCE.md) as
# pile code, so its calls to the llong routines are reloc-free pile calls.  The
# fpsim module (src/modules/fpsim) assembles it with d_glue.s, the entry-point
# layer, and serves every program from one copy.  It is built without loop-top
# safepoints: every loop in it is bounded, and one shared copy must run each
# call to completion.  lib/libdouble/d_stub.s holds the stubs a program's code
# and libc call; each calls the module through the bank-0 vector FPSIM_TRAMP.
lib/libdouble/softdouble.s: fcc lib/libdouble/softdouble.c
	./fcc --pile -fno-safepoints \
	    --data-segment lib/libdouble/softdouble.data.s \
	    lib/libdouble/softdouble.c -o lib/libdouble/softdouble.s

# The linker and library self-tests: the shared libraries, the dynamic and
# static link paths, and fgx_ar on archives each test builds for itself.
test-libs: fcc lib/libc.so.1.0 lib/libtermlib.so.1.0 lib/libcurses.so.1.0 lib/libfgx.so.1.0 lib/libutil.so.1.0 lib/libfgx.s
	python3 tests/ld/test_lib_boundary.py
	python3 tests/libso/test_libso.py
	python3 ../tools/check_libso_identity.py --self-test
	python3 ../tools/check_libso_identity.py
	python3 src/ld/fgx_libso.py --self-test
	python3 src/ld/fgx_imports.py --self-test
	python3 src/ld/fgx_sites.py --self-test
	python3 src/ld/test_fgx_ld_library.py
	python3 ../tools/helper_census.py --check
	for l in libc libtermlib libcurses libfgx libutil; do python3 ../tools/libc_so_check.py --lib $$l --self-test && python3 ../tools/libc_so_check.py --lib $$l || exit 1; done
	python3 src/ld/fgx_dyn.py --self-test
	python3 src/ld/fgx_pack.py --self-test
	python3 src/ld/fgx_static.py --self-test
	python3 tests/dyn/test_dyn.py
	python3 tests/dyn/test_bind.py
	python3 ../tools/check_libc_data.py --self-test
	python3 ../tools/check_libc_data.py
	python3 tests/ld/test_asm_archive.py
	python3 tests/ld/test_c_archive.py
	python3 src/ld/test_fgx_ar.py
	python3 tests/ld/test_data_fit.py
	python3 tests/ld/test_farjump.py
	python3 tests/ld/test_offset_relocs.py

# The use-before-set warning's own fixture: BOTH directions, because a warning
# that fires on everything is noise and one that fires on nothing is decoration.
# The golden suite cannot cover it -- it diffs .s output and this is a stderr
# diagnostic -- so it is a script, like the library self-tests above.
test-warn: fcc
	python3 tests/warn/test_uninit_warn.py

test: fcc test-libs test-warn
	tests/run.sh

test-peephole:
	$(CC) $(CFLAGS) -o /tmp/fcc_test_peephole \
	    tests/peephole/test_peephole.c src/cc/peephole.c
	/tmp/fcc_test_peephole

test-lex:
	$(CC) $(CFLAGS) -DFCC_LEX_TEST -o /tmp/fcc_test_lex \
	    tests/lex/test_peek.c src/cc/lex_pp.c src/cc/globals.c
	/tmp/fcc_test_lex

clean:
	rm -f fcc fas
