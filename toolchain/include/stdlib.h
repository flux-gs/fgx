/* FGX libc — stdlib.h. */
#ifndef _STDLIB_H
#define _STDLIB_H

#ifndef NULL
#define NULL ((char *)0)
#endif

/* malloc takes the FULL 32-bit size_t.  Small requests come from the process
 * break (sbrk, in the data bank, so fork's snapshot carries them); requests
 * >= $F000 come back as a dedicated multi-bank MM block, so malloc(80000L) is
 * real.  realloc refuses the big shape in BOTH directions -- a new size
 * >= $F000, or an old pointer that IS a big block -- and returns NULL/ENOMEM:
 * a dedicated block carries no length libc can read. */
void *malloc(unsigned long size);
void  free(void *p);
void *realloc(void *p, unsigned long size);
int   atoi(char *s);
long  atol(char *s);
double atof(char *s);   /* 4.3BSD-Reno's IEEE atof; see libc_c/atof.c */
long  strtol(char *s, char **endp, int base);
int   abs(int n);
long  labs(long j);
void  exit(int status);
char *getenv(char *name);       /* far-ptr return -> needs the prototype in scope */
int setenv();                  /* (name, value, rewrite); no prototype: su(1) has its own */
void unsetenv();

/* One shared 32-bit LCG (see libc_c.c): rand() is 15-bit, random() is
 * 31-bit (two steps spliced); srand/srandom seed the same state. */
int   rand(void);
void  srand(int seed);
long  random(void);
void  srandom(int seed);
void  qsort(void *base, int n, int size, int (*cmp)(void *, void *));
void *calloc(int n, int size);
int   getuid(void);
int   geteuid(void);
int   getgid(void);
int   getegid(void);

/* BSD getopt(3) — implemented in the libc pile; the cells are pile data. */
int   getopt(int argc, char **argv, char *ostr);
extern int   optind;
/* optreset -- 2.11BSD's getopt(3) extension: set it to make the next getopt
 * start a fresh scan.  A program that parses two argument vectors needs it;
 * mount(8) is the one here.  See libc_c/getopt.c. */
extern int   optreset;
extern int   opterr;
extern int   optopt;
extern char *optarg;

#endif
