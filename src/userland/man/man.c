/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD man(1)
 *   Ported from man(1), 2.11BSD (man.c 5.17.1, 2.11BSD, 1999/11/26).
 *   Original work: Copyright (c) 1987 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX changes
 *   are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * man -- locate and display a manual page.  Exactly like 2.11BSD's man.c this
 * is a cat-page LOCATOR, not a formatter: it resolves /usr/man/cat<N>/<name>.<N>
 * and hands the pre-formatted page to more(1) via system().  The pages are nroff
 * "cat" output pre-converted to FGX SGR + CR at build time by
 * tools/man_preformat.py (overstrike -> bold/underline; see that file and
 * src/userland/man/pages/README.md).
 *
 * FGX/fcc adaptations (no feature loss for the catman model):
 *  - One compiled-in manual root "/usr/man" (2.11BSD's DEF_PATH head) and pager
 *    "more".  FGX has no environ yet (getenv() returns NULL), so upstream's
 *    MANPATH/PAGER env branches and the DEF_PATH multi-root list collapse to a
 *    single root + more -- exactly upstream's behaviour when those vars are
 *    unset.  Pages are the formatted-page layout cat<N>/<name>.<N> (the modern
 *    BSD convention; 2.11BSD's older cat pages used a flat ".0" suffix).
 *  - getopt's "-M/-P/-a/-f/-k/-w" thicket -> a hand-rolled arg scan (the
 *    strings/grep/ul idiom; fcc can't parse 2.11BSD's getopt.c).  Kept: "-"
 *    (cat to stdout) and an explicit section digit.  Dropped (post-v1; noted,
 *    not faked): -a (multi-root all), -M (alt root), -f/-k (whatis/apropos).
 *  - The MANDIR list1[]/list2[] string-pointer tables -> an inline search in
 *    the same order (cat1,cat8,cat6 then cat2,cat3,cat4,cat5,cat7); avoids a
 *    global array-of-pointers initializer (an open fcc gap; matters for vi).
 *  - access(path,R_OK) -> a fopen(path,"r") existence probe (fcc libc has
 *    fopen, not access).  The page is then shown with system("more path"), so
 *    man needs no read/write loop of its own (upstream's cat()).
 *  - !isatty(1) -> cat mode, like upstream, so `man foo | wc` and redirects
 *    dump the raw page instead of paging.
 *  - Multiple names page one-at-a-time (one more per page) rather than batching
 *    a single pager argv (upstream's realloc'd command) -- indistinguishable
 *    for the common single-name case.
 */

#include <stdio.h>

/* libc decls not provided by <stdio.h>; fcc needs a prototype even for bound
 * calls.  system() is posix_spawn(/bin/sh -c cmd)+wait. */
void  exit(int code);
int   isatty(int fd);
int   system(char *cmd);
char *strcpy(char *d, char *s);
char *strcat(char *d, char *s);

#ifndef MANROOT                 /* overridable for host-clang validation */
#define MANROOT "/usr/man"
#endif
#define PAGER   "more"

char path[128];                 /* constructed /usr/man/cat<N>/<name>.<N> */
char cmd[160];                  /* "more <path>" or "cat <path>" */
char sect[8];                   /* "cat<N>" from an explicit section digit */
int  catmode;                   /* 1 = cat page to stdout, 0 = page via more */

/* ANSI forward prototypes (tools/ansify.sh via cproto) */
int  main(int argc, char **argv);
int  page_exists(char *dir, char *name);
void show(void);
int  search(char *name);
int  section_dir(char *arg);
void noentry(char *name);
void usage(void);

/* Build MANROOT/cat<N>/name.<N> into `path`; return 1 if that file exists.
 * `dir` is always "cat<N>", so the file suffix is its trailing section digit
 * (dir[3]): /usr/man/cat1/ls.1.  Mirrors the modern BSD formatted-page layout. */
int page_exists(char *dir, char *name)
{
    FILE *f;
    char  suf[3];

    strcpy(path, MANROOT);
    strcat(path, "/");
    strcat(path, dir);
    strcat(path, "/");
    strcat(path, name);
    suf[0] = '.';
    suf[1] = dir[3];            /* "cat1" -> '1', "cat8" -> '8' */
    suf[2] = 0;
    strcat(path, suf);
    f = fopen(path, "r");
    if (f == NULL)
        return 0;
    fclose(f);
    return 1;
}

/* Display the page now in `path`: cat to stdout, or page via more. */
void show(void)
{
    if (catmode)
        strcpy(cmd, "cat ");
    else {
        strcpy(cmd, PAGER);
        strcat(cmd, " ");
    }
    strcat(cmd, path);
    system(cmd);
}

/* Search the default section order for `name`; show + return 1 on first hit.
 * Order mirrors 2.11BSD man.c: list1 (cat1,cat8,cat6) then list2
 * (cat2,cat3,cat4,cat5,cat7). */
int search(char *name)
{
    if (page_exists("cat1", name)) { show(); return 1; }
    if (page_exists("cat8", name)) { show(); return 1; }
    if (page_exists("cat6", name)) { show(); return 1; }
    if (page_exists("cat2", name)) { show(); return 1; }
    if (page_exists("cat3", name)) { show(); return 1; }
    if (page_exists("cat4", name)) { show(); return 1; }
    if (page_exists("cat5", name)) { show(); return 1; }
    if (page_exists("cat7", name)) { show(); return 1; }
    return 0;
}

/* If `arg` is a lone section digit 1..8, set sect="cat<N>" and return 1. */
int section_dir(char *arg)
{
    if (arg[0] >= '1' && arg[0] <= '8' && arg[1] == 0) {
        sect[0] = 'c'; sect[1] = 'a'; sect[2] = 't';
        sect[3] = arg[0]; sect[4] = 0;
        return 1;
    }
    return 0;
}

void noentry(char *name)
{
    fprintf(stderr, "man: no entry for %s\n", name);
    exit(1);
}

void usage(void)
{
    fprintf(stderr, "usage: man [-] [section] name ...\n");
    exit(1);
}

int main(int argc, char **argv)
{
    int   i;
    char *a;
    int   have_sect;

    /* Non-interactive stdout (pipe/file) -> cat, like man.c's !isatty(1). */
    catmode = 0;
    if (!isatty(1))
        catmode = 1;

    i = 1;
    if (i < argc && argv[i][0] == '-' && argv[i][1] == 0) {
        catmode = 1;                    /* explicit "-" */
        i++;
    }
    if (i >= argc)
        usage();

    have_sect = 0;
    for (; i < argc; i++) {
        a = argv[i];
        if (!have_sect && section_dir(a)) {
            have_sect = 1;              /* next operand is the page name */
            continue;
        }
        if (have_sect) {
            if (page_exists(sect, a))
                show();
            else
                noentry(a);
            have_sect = 0;
        } else {
            if (!search(a))
                noentry(a);
        }
    }
    /* A trailing section digit with no name (e.g. `man 1`) is a usage error. */
    if (have_sect)
        usage();
    exit(0);
    return 0;
}
