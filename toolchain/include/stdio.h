/* FGX libc — stdio.h.  BSD-shape unbuffered stdio.
 * FILE * is an opaque ptr to libc's __sFILE table entry. */
#ifndef _STDIO_H
#define _STDIO_H

struct __sFILE;
typedef struct __sFILE FILE;
typedef unsigned long size_t;   /* 32-bit (train-2 M-4; was int) */

extern FILE *stdin;
extern FILE *stdout;
extern FILE *stderr;

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#define EOF (-1)
#ifndef NULL
#define NULL ((char *)0)
#endif

#ifndef BUFSIZ
#define BUFSIZ 1024
#endif

/* ANSI: longest filename stdio promises to handle.  PATH_MAX (limits.h)
 * is the same 128 -- ProDOS full paths, see sys/param.h MAXPATHLEN. */
#define FILENAME_MAX 128

int puts(char *s);
int printf(char *fmt, ...);
int fprintf(FILE *fp, char *fmt, ...);
int sprintf(char *buf, char *fmt, ...);
int snprintf(char *buf, int sz, char *fmt, ...);
int vsprintf(char *buf, char *fmt, char *ap);   /* ap: va_list (<stdarg.h>) */
int vsnprintf(char *buf, int sz, char *fmt, char *ap);
int vfprintf(FILE *fp, char *fmt, char *ap);    /* ...and err(3)'s two */
int vprintf(char *fmt, char *ap);
int scanf(char *fmt, ...);
int fscanf(FILE *fp, char *fmt, ...);
int sscanf(char *s, char *fmt, ...);

FILE *fopen(char *path, char *mode);
FILE *fdopen(int fd, char *mode);   /* wrap an open fd; "a" seeks to the end */
FILE *freopen(char *path, char *mode, FILE *stream);
int   fclose(FILE *fp);

/* popen/pclose: STUB on FGX (no pipe/fork-to-a-program yet).  popen() returns
 * NULL so a BSD caller degrades gracefully; pclose() returns -1.  Becomes a
 * real spawn+pipe when FGX grows pipes. */
FILE *popen(char *cmd, char *mode);
int   pclose(FILE *fp);
/* COMPLETE ITEMS moved (2.11BSD stdio/fread.c, fwrite.c), not the byte count:
 * a partial item is not counted and its bytes are gone.  Both loop until the
 * count is met or the transfer stops. */
int   fread(void *buf, int sz, int n, FILE *fp);
int   fwrite(void *buf, int sz, int n, FILE *fp);
int   fgetc(FILE *fp);
int   getc(FILE *fp);
int   getchar(void);
int   ungetc(int c, FILE *fp);  /* one pushback; needs an allocated read buffer */
int   fputc(int c, FILE *fp);
int   putc(int c, FILE *fp);
int   fflush(FILE *fp);
int   fputs(char *s, FILE *fp);
int   putchar(int c);
int   feof(FILE *fp);
int   ferror(FILE *fp);
void  clearerr(FILE *fp);

int   fseek(FILE *fp, long off, int whence);
long  ftell(FILE *fp);
void  rewind(FILE *fp);
char *fgets(char *s, int size, FILE *fp);
char *gets(char *s);            /* unsafe (no bound); 2.11BSD telnet command mode */
void  setbuf(FILE *fp, char *buf);   /* no-op: FGX stdio is unbuffered */
int   fileno(FILE *fp);

/* rename(2) lives in lib/libc_c/syscall_file.c and had no declaration in any
 * header, so every caller reached it through an implicit int.  ANSI puts it
 * here. */
int   rename(char *from, char *to);

void  perror(char *msg);


void setbuffer(FILE *fp, char *buf, int size);  /* no-op: stdio is unbuffered */
int   setlinebuf(FILE *fp);          /* no-op: stdio is unbuffered */

#endif
