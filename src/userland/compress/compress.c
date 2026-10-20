/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD compress(1)
 *   Ported from compress(1), 2.11BSD (compress.c 5.9, Berkeley 5/11/86).
 *   Compress - data compression program (LZW, Terry A. Welch / IEEE
 *   Computer, June 1984).  Authors: Spencer W. Thomas, Jim McKie,
 *   Steve Davies, Ken Turkowski, James A. Woods, Joe Orost.
 *   Copyright (c) Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX adaptations (mechanical port; the LZW core is byte-for-byte identical):
 *   - "Normal machine" typedefs only, forced to the NO_UCHAR path:
 *       code_int / count_int = long, char_type = signed char.  code_int must
 *       be long because decoding 16-bit codes needs values up to 2^16, which
 *       does not fit fcc's 16-bit int.
 *   - htab[] / codetab[] are malloc'd (file-scope pointers), never static:
 *       FGX's data bank is 64 KB and a wide LZW table is far larger.
 *   - Compress emits at most 12-bit codes (BITS = 12); the -b flag is clamped
 *       to 12 for compression.  Decompress accepts the file header's maxbits.
 *   - No SIGSEGV/oops() (no SIGSEGV on FGX); SIGINT is kept for temp cleanup.
 *       oops() was the CORRUPT-INPUT detector, not a debug aid, so #17 puts
 *       its check back explicitly -- see DE_STACK_SIZE and corrupt_input().
 *   - No TIOCGPGRP background probe (no ioctl); bgnd_flag hardcoded to 0.
 *   - copystat() keeps the stat + replace-original, but chmod/chown/utime are
 *       deferred (those syscalls do not exist yet on FGX) — #if 0'd out.
 *   - rindex() -> strrchr() (FGX libc has strrchr, not rindex).
 *   - .Z suffix match is CASE-INSENSITIVE (has_z_suffix): ProDOS is a
 *       case-insensitive filesystem and FGX displays names lowercase, so a
 *       user types the ".z" that ls shows.  BSD's case-sensitive strcmp(".Z")
 *       would then re-append .Z ("hello.s.z.Z: No such file"); we accept .z/.Z.
 *   - DEBUG/vax/XENIX_16/interdata/... paths removed.
 *
 * FGX malloc ceiling RETIRED (train-2 M-4, 2026-07-17): malloc takes the
 * full 32-bit size_t and >64 KB requests come back as dedicated MM blocks,
 * so decode tables for foreign -b 13..16 files allocate for real — the
 * shipped "needs N-bit tables, too large for this machine" bridge
 * limitation is gone.  Compression stays <= 12-bit (BITS/HSIZE sizing).
 */
static char rcs_ident[] = "compress.c 5.9 (Berkeley) 5/11/86";

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/stat.h>

#define min(a,b)	((a>b) ? b : a)

#define BITS		12		/* max bits/code for compression */
#define HSIZE		5003		/* 80% occupancy (BITS <= 12) */

typedef long int	code_int;
typedef long int	count_int;
typedef char		char_type;

char_type magic_header[] = { "\037\235" };	/* 1F 9D */

/* Defines for third byte of header */
#define BIT_MASK	0x1f
#define BLOCK_MASK	0x80
#define INIT_BITS	9		/* initial number of bits/code */

#define ARGVAL() (*++(*argv) || (--argc && *++argv))

int n_bits;				/* number of bits/code */
int maxbits = BITS;			/* user settable max # bits/code */
code_int maxcode;			/* maximum code, given n_bits */
code_int maxmaxcode = 1L << BITS;	/* should NEVER generate this code */

#define MAXCODE(n_bits)	((1L << (n_bits)) - 1)

/*
 * Tables live in malloc'd storage (see main()).  htab is count_int-wide;
 * codetab is unsigned short.  The decompress tables overlay these bases
 * exactly as the original overlaid the static arrays:
 *   tab_prefix  -> codetab
 *   tab_suffix  -> htab (as bytes)
 *   de_stack    -> htab, just past tab_suffix (uses runtime maxbits)
 */
count_int *htab;
unsigned short *codetab;

#define htabof(i)	htab[i]
#define codetabof(i)	codetab[i]

#define tab_prefixof(i)	codetabof(i)
#define tab_suffixof(i)	((char_type *)(htab))[i]
/* de_stack: FGX M-4 — its OWN allocation, not the classic overlay at
 * &htab[1<<maxbits].  For maxbits=16 the overlay materializes a far
 * pointer PAST the 64KB bank boundary of the htab block, and fcc's
 * pointer ARITHMETIC is offset-only (single-bank model; long-INDEXED
 * dereferences do carry the bank, so the table subscripts are fine).
 * A separate block keeps every materialized pointer inside its own bank.
 *
 * DE_STACK_SIZE is a BOUND, not headroom (apple/fgx#17).  The original relied
 * on `signal(SIGSEGV, oops)` to catch a runaway decode stack -- its handler
 * says so outright, "wild pointer -- assume bad input" -- because a corrupt
 * .Z whose prefix chain contains a CYCLE walks tab_prefixof forever.  FGX has
 * no MMU and cannot deliver SIGSEGV, and the port dropped oops() without
 * replacing it, so the overrun ran straight off this block and scribbled the
 * malloc arena in silence.  The check below restores the contract and is
 * strictly better than upstream's: deterministic instead of fault-dependent.
 *
 * Why 8192 is a real bound and not a guess.  In a well-formed stream every
 * entry's prefix is a STRICTLY SMALLER code, so a chain cannot cycle and its
 * length is the length of the string that code represents.  Strings grow
 * fastest on a run of one byte, where LZW emits lengths 1,2,3,... -- so a
 * chain of L needs about L*L/2 input bytes.  L=8192 therefore needs ~33 MB,
 * more than a ProDOS volume holds; nothing this machine can store decodes
 * deeper.  Anything that does is a cycle, i.e. corrupt, which is exactly what
 * we report.
 *
 * And a cycle is REACHABLE here in a way it was not upstream: BSD's codetab is
 * `unsigned short codetab[HSIZE]`, a static array, so every entry the stream
 * never wrote read back 0 -- below 256, so the walk stopped at once.  Ours is
 * malloc'd (the tables are too big for a 64 KB data bank), so an unwritten
 * entry reads GARBAGE, and garbage >= 256 chains onward.  Zeroing 128 KB of
 * codetab on every open would restore BSD's accident; bounding the walk fixes
 * the actual hazard and reports the bad file instead of decoding it to
 * nonsense, which is what BSD did in that case. */
#define DE_STACK_SIZE	8192

char_type *de_stack;
char_type *de_stack_end;	/* de_stack + DE_STACK_SIZE; both in one bank,
				 * so fcc's offset-only compare is correct */

code_int hsize = HSIZE;			/* for dynamic table sizing */
count_int fsize;

code_int free_ent = 0;			/* first unused entry */
int exit_stat = 0;			/* per-file status */
int perm_stat = 0;			/* permanent status */

int nomagic = 0;	/* Use a 3-byte magic number header, unless old file */
int zcat_flg = 0;	/* Write output on stdout, suppress messages */
int precious = 1;	/* Don't unlink output file on interrupt */
int quiet = 1;		/* don't tell me about compression */

/*
 * block compression parameters -- after all codes are used up,
 * and compression rate changes, start over.
 */
int block_compress = BLOCK_MASK;
int clear_flg = 0;
long int ratio = 0;
#define CHECK_GAP 10000		/* ratio check interval */
count_int checkpoint = CHECK_GAP;
#define FIRST	257		/* first free entry */
#define CLEAR	256		/* table clear output code */

int force = 0;
char ofname[100];
int bgnd_flag;

int do_decomp = 0;

code_int getcode();
int onintr();
int compress();
int decompress();
int output();
int cl_block();
int cl_hash();
int copystat();
int writeerr();
int version();
int Usage();
int has_z_suffix();
int corrupt_input();

/*
 * FGX: case-insensitive ".Z" suffix test.  ProDOS is case-insensitive and ls
 * shows names lowercase, so a user types ".z"; BSD's case-sensitive strcmp
 * would miss it and re-append .Z.  Also guards names shorter than 2 chars
 * (the original strcmp(*fileptr + strlen-2, ...) underflowed on those).
 */
int has_z_suffix(name)
	char *name;
{
	int n = strlen(name);
	return n >= 2 && name[n - 2] == '.' && (name[n - 1] == 'Z' || name[n - 1] == 'z');
}

int Usage()
{
	fprintf(stderr, "Usage: compress [-fvc] [-b maxbits] [file ...]\n");
	return 0;
}

/*****************************************************************
 * main
 *
 * Usage: compress [-dfvc] [-b bits] [file ...]
 */
int main(argc, argv)
	register int argc;
	char **argv;
{
	int overwrite = 0;	/* Do not overwrite unless given -f flag */
	char tempname[100];
	char **filelist, **fileptr;
	char *cp;
	struct stat statbuf;
	long need;

	/* FGX: single-user; install SIGINT for temp-file cleanup, and there
	 * is no shell-set SIG_IGN background state to preserve.  No SIGSEGV. */
	signal(SIGINT, onintr);
	bgnd_flag = 0;

	filelist = fileptr = (char **)(malloc(argc * sizeof(*argv)));
	*filelist = NULL;

	if ((cp = strrchr(argv[0], '/')) != 0) {
		cp++;
	} else {
		cp = argv[0];
	}
	if (strcmp(cp, "uncompress") == 0) {
		do_decomp = 1;
	} else if (strcmp(cp, "zcat") == 0) {
		do_decomp = 1;
		zcat_flg = 1;
	}

	/* Argument Processing */
	for (argc--, argv++; argc > 0; argc--, argv++) {
		if (**argv == '-') {	/* A flag argument */
			while (*++(*argv)) {	/* Process all flags in this arg */
				switch (**argv) {
				case 'V':
					version();
					break;
				case 'v':
					quiet = 0;
					break;
				case 'd':
					do_decomp = 1;
					break;
				case 'f':
				case 'F':
					overwrite = 1;
					force = 1;
					break;
				case 'n':
					nomagic = 1;
					break;
				case 'C':
					block_compress = 0;
					break;
				case 'b':
					if (!ARGVAL()) {
						fprintf(stderr, "Missing maxbits\n");
						Usage();
						exit(1);
					}
					maxbits = atoi(*argv);
					goto nextarg;
				case 'c':
					zcat_flg = 1;
					break;
				case 'q':
					quiet = 1;
					break;
				default:
					fprintf(stderr, "Unknown flag: '%c'; ", **argv);
					Usage();
					exit(1);
				}
			}
		} else {		/* Input file name */
			*fileptr++ = *argv;	/* Build input file list */
			*fileptr = NULL;
		}
		nextarg: continue;
	}

	if (maxbits < INIT_BITS) maxbits = INIT_BITS;
	if (maxbits > BITS) maxbits = BITS;	/* compress capped at 12 */
	maxmaxcode = 1L << maxbits;

	if (*filelist != NULL) {
		for (fileptr = filelist; *fileptr; fileptr++) {
			exit_stat = 0;
			if (do_decomp) {			/* DECOMPRESSION */
				/* Check for .Z suffix (case-insensitive on FGX) */
				if (!has_z_suffix(*fileptr)) {
					/* No .Z: tack one on */
					strcpy(tempname, *fileptr);
					strcat(tempname, ".Z");
					*fileptr = tempname;
				}
				/* Open input file */
				if ((freopen(*fileptr, "r", stdin)) == NULL) {
					perror(*fileptr);
					perm_stat = 1;
					continue;
				}
				/* Check the magic number */
				if (nomagic == 0) {
					if ((getchar() != (magic_header[0] & 0xFF))
					 || (getchar() != (magic_header[1] & 0xFF))) {
						fprintf(stderr, "%s: not in compressed format\n",
						    *fileptr);
						continue;
					}
					maxbits = getchar();	/* set -b from file */
					block_compress = maxbits & BLOCK_MASK;
					maxbits &= BIT_MASK;
					maxmaxcode = 1L << maxbits;
					if (maxbits > 16) {
						fprintf(stderr,
						"%s: compressed with %d bits, can only handle 16 bits\n",
						    *fileptr, maxbits);
						continue;
					}
				}
				/* Generate output filename */
				strcpy(ofname, *fileptr);
				ofname[strlen(*fileptr) - 2] = '\0';  /* Strip off .Z */
			} else {				/* COMPRESSION */
				if (has_z_suffix(*fileptr)) {
					fprintf(stderr, "%s: already has .Z suffix -- no change\n",
					    *fileptr);
					continue;
				}
				/* Open input file */
				if ((freopen(*fileptr, "r", stdin)) == NULL) {
					perror(*fileptr);
					perm_stat = 1;
					continue;
				}
				stat(*fileptr, &statbuf);
				fsize = (long) statbuf.st_size;
				/*
				 * tune hash table size for small files.  HSIZE (5003)
				 * is the upper bound on output codes here.
				 */
				hsize = HSIZE;
				if (fsize < (1 << 12))
					hsize = min(5003, HSIZE);
				else if (fsize < (1 << 13))
					hsize = min(9001, HSIZE);
				else if (fsize < (1 << 14))
					hsize = min(18013, HSIZE);
				else if (fsize < (1 << 15))
					hsize = min(35023, HSIZE);
				else if (fsize < 47000)
					hsize = min(50021, HSIZE);

				/* Generate output filename */
				strcpy(ofname, *fileptr);
				if ((cp = strrchr(ofname, '/')) != NULL)	cp++;
				else						cp = ofname;
				if (strlen(cp) > 12) {
					fprintf(stderr, "%s: filename too long to tack on .Z\n", cp);
					continue;
				}
				strcat(ofname, ".Z");
			}

			/*
			 * Allocate the tables now that the mode (and, for decode,
			 * the file's maxbits) are known.
			 */
			if (do_decomp) {
				/* M-4: sizes pass as full 32-bit size_t — a
				 * 16-bit table is 128 KB and lands in a
				 * dedicated MM block. */
				need = ((long)1 << maxbits);		/* # of codes */
				codetab = (unsigned short *)malloc(need * (long)sizeof(unsigned short));
				htab = (count_int *)malloc(need * (long)sizeof(char_type));
				de_stack = (char_type *)malloc((long)DE_STACK_SIZE);
				de_stack_end = de_stack + DE_STACK_SIZE;
			} else {
				htab = (count_int *)malloc(HSIZE * (long)sizeof(count_int));
				codetab = (unsigned short *)malloc(HSIZE * (long)sizeof(unsigned short));
			}
			if (htab == NULL || codetab == NULL
			 || (do_decomp && de_stack == NULL)) {
				fprintf(stderr, "%s: out of memory\n", *fileptr);
				perm_stat = 1;
				continue;
			}

			/* Check for overwrite of existing file */
			if (overwrite == 0 && zcat_flg == 0) {
				if (stat(ofname, &statbuf) == 0) {
					char response[2];
					response[0] = 'n';
					fprintf(stderr, "%s already exists;", ofname);
					if (bgnd_flag == 0 && isatty(2)) {
						fprintf(stderr, " do you wish to overwrite %s (y or n)? ",
						ofname);
						fflush(stderr);
						read(2, response, 2);
						while (response[1] != '\n') {
							if (read(2, response+1, 1) < 0) {	/* Ack! */
								perror("stderr"); break;
							}
						}
					}
					if (response[0] != 'y') {
						fprintf(stderr, "\tnot overwritten\n");
						continue;
					}
				}
			}
			if (zcat_flg == 0) {		/* Open output file */
				if (freopen(ofname, "w", stdout) == NULL) {
					perror(ofname);
					perm_stat = 1;
					continue;
				}
				precious = 0;
				if (!quiet)
					fprintf(stderr, "%s: ", *fileptr);
			}

			/* Actually do the compression/decompression */
			if (do_decomp == 0)	compress();
			else			decompress();
			if (zcat_flg == 0) {
				copystat(*fileptr, ofname);	/* Copy stats */
				precious = 1;
				if ((exit_stat == 1) || (!quiet))
					putc('\n', stderr);
			}

			free((void *)htab);
			free((void *)codetab);
			htab = NULL;
			codetab = NULL;
		}
	} else {		/* Standard input */
		if (do_decomp == 0) {
			htab = (count_int *)malloc((int)(HSIZE * (long)sizeof(count_int)));
			codetab = (unsigned short *)malloc((int)(HSIZE * (long)sizeof(unsigned short)));
			if (htab == NULL || codetab == NULL) {
				fprintf(stderr, "stdin: out of memory\n");
				exit(1);
			}
			compress();
			if (!quiet)
				putc('\n', stderr);
		} else {
			/* Check the magic number */
			if (nomagic == 0) {
				if ((getchar() != (magic_header[0] & 0xFF))
				 || (getchar() != (magic_header[1] & 0xFF))) {
					fprintf(stderr, "stdin: not in compressed format\n");
					exit(1);
				}
				maxbits = getchar();	/* set -b from file */
				block_compress = maxbits & BLOCK_MASK;
				maxbits &= BIT_MASK;
				maxmaxcode = 1L << maxbits;
				fsize = 100000;		/* assume stdin large */
				if (maxbits > 16) {
					fprintf(stderr,
					"stdin: compressed with %d bits, can only handle 16 bits\n",
					    maxbits);
					exit(1);
				}
			}
			need = ((long)1 << maxbits);
			codetab = (unsigned short *)malloc(need * (long)sizeof(unsigned short));
			htab = (count_int *)malloc(need * (long)sizeof(char_type));
			de_stack = (char_type *)malloc((long)DE_STACK_SIZE);
			de_stack_end = de_stack + DE_STACK_SIZE;
			if (htab == NULL || codetab == NULL || de_stack == NULL) {
				fprintf(stderr, "stdin: out of memory\n");
				exit(1);
			}
			decompress();
		}
	}
	exit(perm_stat ? perm_stat : exit_stat);
	return 0;
}

static int offset;
long int in_count = 1;			/* length of input */
long int bytes_out;			/* length of compressed output */
long int out_count = 0;			/* # of codes output (for debugging) */

/*
 * compress stdin to stdout
 */
int compress()
{
	register long fcode;
	register code_int i = 0;
	register int c;
	register code_int ent;
	register int disp;
	register code_int hsize_reg;
	register int hshift;

	if (nomagic == 0) {
		putchar(magic_header[0]); putchar(magic_header[1]);
		putchar((char)(maxbits | block_compress));
		if (ferror(stdout))
			writeerr();
	}

	offset = 0;
	bytes_out = 3;		/* includes 3-byte header mojo */
	out_count = 0;
	clear_flg = 0;
	ratio = 0;
	in_count = 1;
	checkpoint = CHECK_GAP;
	maxcode = MAXCODE(n_bits = INIT_BITS);
	free_ent = ((block_compress) ? FIRST : 256);

	ent = getchar();

	hshift = 0;
	for (fcode = (long) hsize; fcode < 65536L; fcode *= 2L)
		hshift++;
	hshift = 8 - hshift;		/* set hash code range bound */

	hsize_reg = hsize;
	cl_hash((count_int) hsize_reg);		/* clear hash table */

	while ((c = getchar()) != EOF) {
		in_count++;
		fcode = (long) (((long) c << maxbits) + ent);
		i = ((c << hshift) ^ ent);	/* xor hashing */

		if (htabof(i) == fcode) {
			ent = codetabof(i);
			continue;
		} else if ((long)htabof(i) < 0)	/* empty slot */
			goto nomatch;
		disp = hsize_reg - i;		/* secondary hash (after G. Knott) */
		if (i == 0)
			disp = 1;
	probe:
		if ((i -= disp) < 0)
			i += hsize_reg;

		if (htabof(i) == fcode) {
			ent = codetabof(i);
			continue;
		}
		if ((long)htabof(i) > 0)
			goto probe;
	nomatch:
		output((code_int) ent);
		out_count++;
		ent = c;
		if (free_ent < maxmaxcode) {
			codetabof(i) = free_ent++;	/* code -> hashtable */
			htabof(i) = fcode;
		}
		else if ((count_int)in_count >= checkpoint && block_compress)
			cl_block();
	}
	/*
	 * Put out the final code.
	 */
	output((code_int)ent);
	out_count++;
	output((code_int)-1);

	/*
	 * Print out stats on stderr
	 */
	if (zcat_flg == 0 && !quiet) {
		fprintf(stderr, "Compression: ");
		prratio(stderr, in_count-bytes_out, in_count);
	}
	if (bytes_out > in_count)	/* exit(2) if no savings */
		exit_stat = 2;
	return 0;
}

/*****************************************************************
 * output
 *
 * Output the given code.
 */

static char buf[BITS];

char_type lmask[9] = {0xff, 0xfe, 0xfc, 0xf8, 0xf0, 0xe0, 0xc0, 0x80, 0x00};
char_type rmask[9] = {0x00, 0x01, 0x03, 0x07, 0x0f, 0x1f, 0x3f, 0x7f, 0xff};

int output(code)
	code_int code;
{
	register int r_off = offset, bits = n_bits;
	register char *bp = buf;

	if (code >= 0) {
		/*
		 * Get to the first byte.
		 */
		bp += (r_off >> 3);
		r_off &= 7;
		/*
		 * Since code is always >= 8 bits, only need to mask the first
		 * hunk on the left.
		 */
		*bp = (*bp & rmask[r_off]) | (code << r_off) & lmask[r_off];
		bp++;
		bits -= (8 - r_off);
		code >>= 8 - r_off;
		/* Get any 8 bit parts in the middle (<=1 for up to 16 bits). */
		if (bits >= 8) {
			*bp++ = code;
			code >>= 8;
			bits -= 8;
		}
		/* Last bits. */
		if (bits)
			*bp = code;
		offset += n_bits;
		if (offset == (n_bits << 3)) {
			bp = buf;
			bits = n_bits;
			bytes_out += bits;
			do
				putchar(*bp++);
			while (--bits);
			offset = 0;
		}

		/*
		 * If the next entry is going to be too big for the code size,
		 * then increase it, if possible.
		 */
		if (free_ent > maxcode || (clear_flg > 0)) {
			/*
			 * Write the whole buffer, because the input side won't
			 * discover the size increase until after it has read it.
			 */
			if (offset > 0) {
				if (fwrite(buf, 1, n_bits, stdout) != n_bits)
					writeerr();
				bytes_out += n_bits;
			}
			offset = 0;

			if (clear_flg) {
				maxcode = MAXCODE(n_bits = INIT_BITS);
				clear_flg = 0;
			}
			else {
				n_bits++;
				if (n_bits == maxbits)
					maxcode = maxmaxcode;
				else
					maxcode = MAXCODE(n_bits);
			}
		}
	} else {
		/*
		 * At EOF, write the rest of the buffer.
		 */
		if (offset > 0)
			fwrite(buf, 1, (offset + 7) / 8, stdout);
		bytes_out += (offset + 7) / 8;
		offset = 0;
		fflush(stdout);
		if (ferror(stdout))
			writeerr();
	}
	return 0;
}

/*
 * Decompress stdin to stdout.
 */
int decompress()
{
	register char_type *stackp;
	register int finchar;
	register code_int code, oldcode, incode;

	/*
	 * As above, initialize the first 256 entries in the table.
	 */
	maxcode = MAXCODE(n_bits = INIT_BITS);
	for (code = 255; code >= 0; code--) {
		tab_prefixof(code) = 0;
		tab_suffixof(code) = (char_type)code;
	}
	free_ent = ((block_compress) ? FIRST : 256);

	finchar = oldcode = getcode();
	if (oldcode == -1)	/* EOF already? */
		return 0;		/* Get out of here */
	putchar((char)finchar);		/* first code must be 8 bits = char */
	if (ferror(stdout))		/* Crash if can't write */
		writeerr();
	stackp = de_stack;

	while ((code = getcode()) > -1) {

		if ((code == CLEAR) && block_compress) {
			for (code = 255; code >= 0; code--)
				tab_prefixof(code) = 0;
			clear_flg = 1;
			free_ent = FIRST - 1;
			if ((code = getcode()) == -1)	/* O, untimely death! */
				break;
		}
		incode = code;
		/*
		 * Special case for KwKwK string.
		 */
		if (code >= free_ent) {
			if (stackp >= de_stack_end)
				corrupt_input();
			*stackp++ = finchar;
			code = oldcode;
		}

		/*
		 * Generate output characters in reverse order.  The bound is #17:
		 * a corrupt .Z can make tab_prefixof cycle, and this loop then runs
		 * off de_stack forever.  Upstream took a SIGSEGV here.
		 */
		while (code >= 256) {
			if (stackp >= de_stack_end)
				corrupt_input();
			*stackp++ = tab_suffixof(code);
			code = tab_prefixof(code);
		}
		if (stackp >= de_stack_end)
			corrupt_input();
		*stackp++ = finchar = tab_suffixof(code);

		/*
		 * And put them out in forward order
		 */
		do
			putchar(*--stackp);
		while (stackp > de_stack);

		/*
		 * Generate the new entry.
		 */
		if ((code = free_ent) < maxmaxcode) {
			tab_prefixof(code) = (unsigned short)oldcode;
			tab_suffixof(code) = finchar;
			free_ent = code+1;
		}
		/*
		 * Remember previous code.
		 */
		oldcode = incode;
	}
	fflush(stdout);
	if (ferror(stdout))
		writeerr();
	return 0;
}

/*****************************************************************
 * getcode
 *
 * Read one code from the standard input.  If EOF, return -1.
 */
code_int getcode()
{
	register code_int code;
	static int offset = 0, size = 0;
	static char_type buf[16];	/* DECODE reads up to n_bits=16 bytes —
					 * sizing this by BITS (the 12-bit
					 * COMPRESSION clamp) overflowed for
					 * foreign -b 13..16 files (M-4) */
	register int r_off, bits;
	register char_type *bp = buf;

	if (clear_flg > 0 || offset >= size || free_ent > maxcode) {
		/*
		 * If the next entry will be too big for the current code
		 * size, then we must increase the size.  This implies reading
		 * a new buffer full, too.
		 */
		if (free_ent > maxcode) {
			n_bits++;
			if (n_bits == maxbits)
				maxcode = maxmaxcode;	/* won't get any bigger now */
			else
				maxcode = MAXCODE(n_bits);
		}
		if (clear_flg > 0) {
			maxcode = MAXCODE(n_bits = INIT_BITS);
			clear_flg = 0;
		}
		size = fread(buf, 1, n_bits, stdin);
		if (size <= 0)
			return -1;			/* end of file */
		offset = 0;
		/* Round size down to integral number of codes */
		size = (size << 3) - (n_bits - 1);
	}
	r_off = offset;
	bits = n_bits;
	/*
	 * Get to the first byte.
	 */
	bp += (r_off >> 3);
	r_off &= 7;
	/* Get first part (low order bits) [NO_UCHAR: mask to 0xff] */
	code = ((*bp++ >> r_off) & rmask[8 - r_off]) & 0xff;
	bits -= (8 - r_off);
	r_off = 8 - r_off;		/* now, offset into code word */
	/* Get any 8 bit parts in the middle (<=1 for up to 16 bits). */
	if (bits >= 8) {
		code |= (*bp++ & 0xff) << r_off;
		r_off += 8;
		bits -= 8;
	}
	/* high order bits. */
	code |= (*bp & rmask[bits]) << r_off;
	offset += n_bits;

	return code;
}

int writeerr()
{
	perror(ofname);
	unlink(ofname);
	exit(1);
	return 0;
}

int copystat(ifname, ofname)
	char *ifname, *ofname;
{
	struct stat statbuf;
	int mode;

	fclose(stdout);
	if (stat(ifname, &statbuf)) {		/* Get stat on input file */
		perror(ifname);
		return 0;
	}
	if ((statbuf.st_mode & S_IFMT) != S_IFREG) {
		if (quiet)
			fprintf(stderr, "%s: ", ifname);
		fprintf(stderr, " -- not a regular file: unchanged");
		exit_stat = 1;
		perm_stat = 1;
	} else if (statbuf.st_nlink > 1) {
		if (quiet)
			fprintf(stderr, "%s: ", ifname);
		fprintf(stderr, " -- has %d other links: unchanged",
			statbuf.st_nlink - 1);
		exit_stat = 1;
		perm_stat = 1;
	} else if (exit_stat == 2 && (!force)) { /* No compression: remove file.Z */
		if (!quiet)
			fprintf(stderr, " -- file unchanged");
	} else {			/* ***** Successful Compression ***** */
		exit_stat = 0;
		mode = statbuf.st_mode & 07777;
#if 0	/* FGX: chmod/chown/utime deferred to SYS_UTIME phase */
		if (chmod(ofname, mode))		/* Copy modes */
			perror(ofname);
		chown(ofname, statbuf.st_uid, statbuf.st_gid);	/* Copy ownership */
		timep[0] = statbuf.st_atime;
		timep[1] = statbuf.st_mtime;
		utime(ofname, timep);	/* Update last accessed and modified times */
#endif
		if (unlink(ifname))	/* Remove input file */
			perror(ifname);
		if (!quiet)
			fprintf(stderr, " -- replaced with %s", ofname);
		return 0;		/* Successful return */
	}

	/* Unsuccessful return -- one of the tests failed */
	if (unlink(ofname))
		perror(ofname);
	return 0;
}

int onintr()
{
	if (!precious)
		unlink(ofname);
	exit(1);
	return 0;
}

/*
 * apple/fgx#17: what upstream's `oops()` did, minus the fault.  The original
 * armed signal(SIGSEGV, oops) and let the MMU notice a runaway decode stack;
 * we detect the overrun directly, so the message and the cleanup are the same
 * but the trigger is deterministic.  Reached only on a cyclic prefix chain --
 * see DE_STACK_SIZE.
 */
int corrupt_input()
{
	fprintf(stderr, "uncompress: corrupt input\n");
	if (!precious)
		unlink(ofname);
	exit(1);
	return 0;
}

int cl_block()		/* table clear for block compress */
{
	register long int rat;

	checkpoint = in_count + CHECK_GAP;

	if (in_count > 0x007fffff) {	/* shift will overflow */
		rat = bytes_out >> 8;
		if (rat == 0) {		/* Don't divide by zero */
			rat = 0x7fffffff;
		} else {
			rat = in_count / rat;
		}
	} else {
		rat = (in_count << 8) / bytes_out;	/* 8 fractional bits */
	}
	if (rat > ratio) {
		ratio = rat;
	} else {
		ratio = 0;
		cl_hash((count_int) hsize);
		free_ent = FIRST;
		clear_flg = 1;
		output((code_int) CLEAR);
	}
	return 0;
}

int cl_hash(hsize)		/* reset code table */
	register count_int hsize;
{
	register count_int *htab_p = htab+hsize;
	register long i;
	register long m1 = -1;

	i = hsize - 16;
	do {				/* might use Sys V memset(3) here */
		*(htab_p-16) = m1;
		*(htab_p-15) = m1;
		*(htab_p-14) = m1;
		*(htab_p-13) = m1;
		*(htab_p-12) = m1;
		*(htab_p-11) = m1;
		*(htab_p-10) = m1;
		*(htab_p-9) = m1;
		*(htab_p-8) = m1;
		*(htab_p-7) = m1;
		*(htab_p-6) = m1;
		*(htab_p-5) = m1;
		*(htab_p-4) = m1;
		*(htab_p-3) = m1;
		*(htab_p-2) = m1;
		*(htab_p-1) = m1;
		htab_p -= 16;
	} while ((i -= 16) >= 0);
	for (i += 16; i > 0; i--)
		*--htab_p = m1;
	return 0;
}

int prratio(stream, num, den)
	FILE *stream;
	long int num, den;
{
	register int q;			/* Doesn't need to be long */

	if (num > 214748L) {		/* 2147483647/10000 */
		q = num / (den / 10000L);
	} else {
		q = 10000L * num / den;		/* Long calculations, though */
	}
	if (q < 0) {
		putc('-', stream);
		q = -q;
	}
	fprintf(stream, "%d.%02d%%", q / 100, q % 100);
	return 0;
}

int version()
{
	fprintf(stderr, "%s\n", rcs_ident);
	fprintf(stderr, "Options: NO_UCHAR, BITS = %d\n", BITS);
	return 0;
}
