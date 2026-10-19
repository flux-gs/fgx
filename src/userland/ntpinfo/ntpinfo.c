/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: FGX-original
 *   ntpinfo -- inspect a NinjaTracker+ (.ntp) module and print its structure
 *   in hex.  C rewrite of the hand-asm ntpinfo.s (H-roadmap H3 rung); the on-
 *   screen output is unchanged.  The .ntp layout is FGX-original knowledge
 *   (re/shellplay/PHASE_A_NOTES.md sec.1) -- no vendored source applies.
 *
 * Format (all multi-byte fields little-endian):
 *   magic   "nfc!" (4)          version (1)
 *   counts  tracks, instr, pat, order, namelen (5)
 *   name    <namelen> bytes
 *   tracks  3 bytes x <tracks>   (byte 2 = the voice's oscillator)
 *   instrs  15-byte prefix x <instr>, each followed by <prefix[14]> name bytes
 *           prefix[0]=type  prefix[1..2]=sample length  prefix[10]=volume
 *
 * fcc adaptations vs the asm (no user-visible change): stdio fopen/fread
 * replaces the libc file shims; hex comes from printf %02X/%04X instead of the
 * hand-rolled nibble emitter; name/skip buffers are 256 bytes (the asm's 64 for
 * a byte-sized length was a latent overflow).
 */
#include <stdio.h>

static FILE *fp;

/* read n bytes; 1 = full read, 0 = short (the caller then prints "short read",
 * mirroring the asm's read-then-report-on-failure flow). */
static int rd(unsigned char *b, int n)
{
	return fread(b, 1, n, fp) == n;
}

/* parse + print the module body.  0 ok, 1 short read, 2 bad magic. */
static int dump(void)
{
	unsigned char magic[4], ver, cnt[5];
	unsigned char nm[256], trk[3], ins[15], skip[256];
	int ntracks, ninstr, namelen, skiplen, i, col;
	unsigned int len;		/* sample length is an unsigned 16-bit field */

	if (!rd(magic, 4))
		return 1;
	if (magic[0] != 'n' || magic[1] != 'f' || magic[2] != 'c' || magic[3] != '!') {
		printf("bad magic\n");
		return 2;
	}
	if (!rd(&ver, 1))
		return 1;
	if (!rd(cnt, 5))
		return 1;
	ntracks = cnt[0];
	ninstr  = cnt[1];
	namelen = cnt[4];

	printf("NTP v%02X trk %02X ins %02X pat %02X ord %02X\n",
	       ver, cnt[0], cnt[1], cnt[2], cnt[3]);

	if (!rd(nm, namelen))
		return 1;
	printf("name ");
	fwrite(nm, 1, namelen, stdout);
	printf("\n");

	/* track table: print each voice's oscillator byte. */
	printf("osc");
	for (i = 0; i < ntracks; i++) {
		if (!rd(trk, 3))
			return 1;
		printf(" %02X", trk[2]);
	}
	printf("\n");

	/* instrument records: two per line ("iNN tTT LLLL vVV"). */
	col = 0;
	for (i = 0; i < ninstr; i++) {
		if (!rd(ins, 15))
			return 1;
		len = (ins[2] << 8) | ins[1];
		printf("i%02X t%02X %04X v%02X", i, ins[0], len, ins[10]);
		if (col == 0) {
			printf("  ");
			col = 1;
		} else {
			printf("\n");
			col = 0;
		}
		skiplen = ins[14];		/* skip the instrument name */
		if (skiplen && !rd(skip, skiplen))
			return 1;
	}
	if (col)				/* flush a half-filled last line */
		printf("\n");
	return 0;
}

int main(int argc, char **argv)
{
	int rc;

	printf("\033[2J\033[H");			/* clear + home (as ntpinfo.s did) */

	if (argc < 2) {
		printf("usage: ntpinfo file\n");
		return 1;
	}
	fp = fopen(argv[1], "r");
	if (fp == NULL) {
		printf("cannot open\n");
		return 1;
	}
	rc = dump();
	fclose(fp);
	if (rc == 1)
		printf("short read\n");
	return rc ? 1 : 0;
}
