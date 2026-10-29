/* FGX libc — string.h. */
#ifndef _STRING_H
#define _STRING_H

#ifndef NULL
#define NULL ((char *)0)
#endif

int   strlen(char *s);
int   strcmp(char *a, char *b);
int   strncmp(char *a, char *b, int n);
char *strcpy(char *d, char *s);
char *strncpy(char *d, char *s, int n);
char *strcat(char *d, char *s);
char *strncat(char *d, char *s, int n);
char *strchr(char *s, int c);
char *strrchr(char *s, int c);
int   strspn(char *s, char *set);
char *strerror(int errnum);      /* errno.h code -> static message (P3-4 I1) */
void  strmode();               /* strmode(mode, buf): mode as ls(1) prints it; buf >= 12 */

void *memcpy(void *d, void *s, int n);
void *memmove(void *d, void *s, int n);   /* overlap-safe */
int   memcmp(void *a, void *b, int n);
void *memset(void *p, int c, unsigned n);
void  bcopy(void *s, void *d, int n);   /* BSD arg order (src, dst); overlap-safe */
void *memchr(void *s, int c, int n);

char *strdup(char *s);

/* strstr(3) and the case-blind compares.  2.11BSD's own, one member each in
 * the pile so a caller of strlen does not pull them in. */
char *strstr(char *s, char *find);
int   strcasecmp(char *s1, char *s2);
int   strncasecmp(char *s1, char *s2, int n);


/* UFS 2.1, for fstab(3): 2.11BSD usr/src/lib/libc/string/{strpbrk,strsep,strtok}.c */
char *strpbrk(char *s1, char *s2);
char *strsep(char **stringp, char *delim);
char *strtok(char *s, char *delim);

#endif
