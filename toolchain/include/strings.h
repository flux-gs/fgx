/* FGX libc — strings.h.  BSD byte/string ops (distinct from ANSI <string.h>). */
#ifndef _STRINGS_H
#define _STRINGS_H
void  bcopy(char *src, char *dst, int n);
void  bzero(char *b, unsigned n);
int   bcmp(char *a, char *b, int n);
char *index(char *s, int c);
char *rindex(char *s, int c);
#endif
