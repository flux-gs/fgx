/* FGX libc -- stdio.h.  2.11BSD's (5.3, 3/15/86): struct _iobuf, the _iob
 * table, and getc/putc as macros on its count and pointer.
 * examples/2.11BSD/usr/include/stdio.h.
 *
 * FGX deltas, each forced:
 *  - NULL is ((char *)0), a 4-byte pointer, where 2.11BSD's 0 is an int:
 *    fcc's pointers carry a bank, and a bare 0 passed where a pointer is
 *    expected leaves the bank half of the argument unpushed.
 *  - Functions are declared with prototypes, so fcc widens and checks their
 *    arguments; the names, argument orders and return types are 2.11BSD's.
 *  - size_t, the SEEK_* names, FILENAME_MAX, setvbuf's _IOFBF, snprintf,
 *    vsnprintf and the v*printf family are ANSI, which FGX's sources use. */
#ifndef _STDIO_H
#define _STDIO_H

#define	BUFSIZ	1024
extern	struct	_iobuf {
	int	_cnt;
	char	*_ptr;		/* should be unsigned char */
	char	*_base;		/* ditto */
	int	_bufsiz;
	short	_flag;
	char	_file;		/* should be short */
} _iob[];

#define	_IOREAD	01
#define	_IOWRT	02
#define	_IONBF	04
#define	_IOMYBUF	010
#define	_IOEOF	020
#define	_IOERR	040
#define	_IOSTRG	0100
#define	_IOLBF	0200
#define	_IORW	0400
#define	_IOFBF	0		/* setvbuf's "fully buffered": no flag set */
#ifndef NULL
#define	NULL	((char *)0)
#endif
#define	FILE	struct _iobuf
#define	EOF	(-1)

typedef unsigned long size_t;

#define	SEEK_SET	0
#define	SEEK_CUR	1
#define	SEEK_END	2

/* ANSI: the longest file name stdio promises to handle.  PATH_MAX
 * (limits.h) is the same 128. */
#define	FILENAME_MAX	128

#define	stdin	(&_iob[0])
#define	stdout	(&_iob[1])
#define	stderr	(&_iob[2])
#define	getc(p)		(--(p)->_cnt>=0? (int)(*(unsigned char *)(p)->_ptr++):_filbuf(p))
#define	getchar()	getc(stdin)
#define putc(x, p)	(--(p)->_cnt >= 0 ?\
	(int)(*(unsigned char *)(p)->_ptr++ = (x)) :\
	(((p)->_flag & _IOLBF) && -(p)->_cnt < (p)->_bufsiz ?\
		((*(p)->_ptr = (x)) != '\n' ?\
			(int)(*(unsigned char *)(p)->_ptr++) :\
			_flsbuf(*(unsigned char *)(p)->_ptr, p)) :\
		_flsbuf((unsigned char)(x), p)))
#define	putchar(x)	putc(x,stdout)
#define	feof(p)		(((p)->_flag&_IOEOF)!=0)
#define	ferror(p)	(((p)->_flag&_IOERR)!=0)
#define	fileno(p)	((p)->_file)
#define	clearerr(p)	((p)->_flag &= ~(_IOERR|_IOEOF))

int	_filbuf(FILE *iop);
int	_flsbuf(int c, FILE *iop);

FILE	*fopen(char *file, char *mode);
FILE	*fdopen(int fd, char *mode);
FILE	*freopen(char *file, char *mode, FILE *iop);
FILE	*popen(char *cmd, char *mode);
int	pclose(FILE *iop);
int	fclose(FILE *iop);
int	fflush(FILE *iop);
long	ftell(FILE *iop);
int	fseek(FILE *iop, long offset, int ptrname);
void	rewind(FILE *iop);
int	fgetc(FILE *iop);
int	fputc(int c, FILE *iop);
char	*fgets(char *s, int n, FILE *iop);
int	fputs(char *s, FILE *iop);
char	*gets(char *s);		/* unbounded: 2.11BSD telnet's command mode */
int	puts(char *s);
int	getw(FILE *iop);
int	putw(int w, FILE *iop);
int	ungetc(int c, FILE *iop);
int	fread(void *ptr, int size, int count, FILE *iop);
int	fwrite(void *ptr, int size, int count, FILE *iop);
void	setbuf(FILE *iop, char *buf);
void	setbuffer(FILE *iop, char *buf, int size);
int	setlinebuf(FILE *iop);
int	setvbuf(FILE *iop, char *buf, int mode, int size);
int	printf(char *fmt, ...);
int	fprintf(FILE *iop, char *fmt, ...);
int	sprintf(char *str, char *fmt, ...);
int	snprintf(char *str, int size, char *fmt, ...);
int	vprintf(char *fmt, char *ap);		/* ap: a va_list (<stdarg.h>) */
int	vfprintf(FILE *iop, char *fmt, char *ap);
int	vsprintf(char *str, char *fmt, char *ap);
int	vsnprintf(char *str, int size, char *fmt, char *ap);
int	scanf(char *fmt, ...);
int	fscanf(FILE *iop, char *fmt, ...);
int	sscanf(char *str, char *fmt, ...);
int	rename(char *from, char *to);
void	perror(char *s);

#endif /* _STDIO_H */
