/* ---------------------------------------------------------------------------
 * Alias wrappers (Stage A2): BSD source names that used to share a pile symbol
 * with a differently-named primitive via the old fcc binding table.  With the
 * table gone, fcc emits the plain source name, so each needs a real (weak) pile
 * export.  Thin delegations — a user program may still override any of them and
 * win at link time (archive-emulation weak/strong).
 * ------------------------------------------------------------------------- */
int getc(char *fp)                     { return fgetc(fp); }
int putc(int c, char *fp)              { return fputc(c, fp); }
/* lstat(2) IS ITS OWN SYSCALL NOW (SYS_LSTAT=111, 2026-09-05).  It was this
 * alias, which made every symlink report its target -- and ls(1) shows a link
 * as a link only because upstream stats with lstat BY DEFAULT
 * (`statf = Lflg ? stat : lstat'), so with the two identical the 'l' type
 * could never appear.  The definition lives in stat.c beside stat's. */
char *rindex(char *s, int c)           { return strrchr(s, c); }
char *index(char *s, int c)            { return strchr(s, c); }   /* UFS 2.1: fstab(3) */

