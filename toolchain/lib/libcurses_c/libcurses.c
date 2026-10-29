/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (usr.lib/libcurses, 4.3BSD curses)
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * lib/libcurses_c/libcurses.c — the curses library pile (BSD-foundations
 * P1 step 4, 2026-07-16; was FGX src/userland/lib/curses/ per-tool TUs).
 * Textual aggregation of the member files into the one --pile TU (the
 * regexp.c pattern): curses.c first (defines the globals; its UP and BC
 * are tentative definitions of libtermlib's), then the members
 * alphabetically.  Compiled
 * with -DNOSCCS (every member's static sccsid[] would collide in one TU).
 * Selected per tool via libs="termlib,curses"; termlib must accompany it
 * (cr_put/cr_tty drive tgoto/tputs).
 */
#include <stdlib.h>              /* wide malloc prototype (M-4) */
/* strcpy/strncpy prototypes: an implicit decl assumes an INT return,
 * which truncates the returned char* bank if a member ever uses it. */
#include <string.h>
#include "curses.c"
#include "addch.c"
#include "addstr.c"
#include "box.c"
#include "clear.c"
#include "clrtobot.c"
#include "clrtoeol.c"
#include "cr_put.c"
#include "cr_tty.c"
#include "delch.c"
#include "deleteln.c"
#include "delwin.c"
#include "endwin.c"
#include "erase.c"
#include "fullname.c"
#include "getch.c"
#include "getstr.c"
#include "id_subwins.c"
#include "idlok.c"
#include "initscr.c"
#include "insch.c"
#include "insertln.c"
#include "keypad.c"
#include "longname.c"
#include "move.c"
#include "mvprintw.c"
#include "mvscanw.c"
#include "mvwin.c"
#include "newwin.c"
#include "overlay.c"
#include "overwrite.c"
#include "printw.c"
#include "putchar.c"
#include "refresh.c"
#include "scanw.c"
#include "scroll.c"
#include "standout.c"
#include "toucholap.c"
#include "touchwin.c"
#include "unctrl.c"
