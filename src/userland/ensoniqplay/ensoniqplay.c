/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: FGX-original
 *   ensoniqplay - play a PCM sample through the Ensoniq 5503 DOC.  C driver
 *   (this file) + companion asm engine (ensoniqplay_stubs.s), the same split as
 *   ntpplay: the DOC / GLU bit-banging is exported asm helpers that pass values
 *   through the non-static C globals below (seg1, reached DBR-relative by bare
 *   name); the file parsing, format conversion, and control flow live here.
 *
 * INPUT FORMATS (MILESTONE 3)
 *   - WAV (RIFF/WAVE): 8-bit (unsigned) or 16-bit (signed) PCM, mono or stereo,
 *     any sample rate -- all read from the header.  16-bit is downconverted to
 *     8-bit, stereo is mixed to mono.
 *   - Raw headerless: 8-bit mono.  Sample rate comes from -r (default 22050).
 *     Signedness defaults to UNSIGNED (the DOC-native, WAV-8-bit convention);
 *     -s/-u force it, and -a autodetects by histogram mode (reliable for real
 *     audio, whose quiet level sits at 128 unsigned / 0 signed -- but genuinely
 *     ambiguous for full-scale tones, hence not the default).
 *
 * PLAYBACK PATHS (dispatch on the converted sample count)
 *   - MILESTONE 1, PLACED (<= 32 KB): uploaded once into DOC wave RAM, played by
 *     one one-shot oscillator; no sound IRQ.  Clean in emulation.
 *   - MILESTONE 2, STREAMED (> 32 KB): held in an mm_alloc'd pool and fed to a
 *     512 B DOC-RAM double-buffer under the sound IRQ (a rate-locked silent
 *     timer oscillator drives refills).  Inherits the streamed-sample static of
 *     docs/history/audits/ntpplay-streaming.md (an es5503 emulation artifact; timing is fine).
 *
 * RATE MATH (validated against docs/history/audits/ntpplay-streaming.md, MAME's es5503, and
 *   libsoundGS): 32 oscillators enabled ($E1=$3E) give scan_rate =
 *   (7.15909 MHz/8)/(32+2) = 894886/34 = 26320 Hz; the sample oscillator runs
 *   at resshift 9, so playback_rate = scan_rate * freq / 512 and
 *   freq = round(rate * 512 / 26320).  A source rate above 26320 Hz (e.g. a
 *   44100 Hz WAV) is integer-DECIMATED (averaging) to <= 26320 so the pitch
 *   stays correct: decim = ceil(rate/26320), effective_rate = rate/decim.
 */
#include <stdio.h>
#include <stdlib.h>	/* atoi */

#define DOC_SCAN_RATE	26320L	/* per-osc DOC service rate, 32 oscs enabled */
#define MAX_PLACED	32768	/* one oscillator addresses a 32 KB wavetable */
#define UPBUF_SZ	4096	/* cooked-output / disk block */
#define OSC_SIZE_32K	0x3F	/* placed: wavetable size 7 (32 KB) + resolution 7 */
#define OSC_CTL_ONESHOT	0x02	/* mode 01 = one-shot, halt bit clear (playing) */
#define STREAM_BASE_PG	0xFC	/* streamed double-buffer at $FC00 (mirror the stub) */
#define CK_EOF		-9999	/* cook_frame end-of-data sentinel */

/* ---- globals shared with ensoniqplay_stubs.s (non-static => seg1, reached by
 *      bare name; the engine reads/writes them DBR-relative). ---- */
unsigned char snd_buf[UPBUF_SZ];	/* cooked (DOC-native) block for the sinks */
int  snd_chunk;				/* valid bytes in snd_buf (placed upload) */
int  snd_page;				/* placed: DOC RAM destination page */
int  snd_freq;				/* DOC 16-bit frequency word */
int  snd_size;				/* placed: DOC wavetable size/resolution register */
int  snd_ctl;				/* placed: DOC oscillator control register */
int  snd_vol;				/* DOC oscillator volume (0..255) */
long snd_tbuf;				/* 4-byte buffer for SYS_TICKS snapshots */

/* streamed-path state (M2) */
unsigned long snd_pool_base;		/* mm_alloc'd pool base (24-bit) */
unsigned long snd_pool_ptr;		/* engine's running read pointer into the pool */
unsigned long snd_pool_end;		/* pool_base + padded size: refill stops here */
int  snd_pg_off;			/* which 256 B half to refill next (0/1) */
int  snd_dst_pg;			/* engine scratch: refill target DOC page */
int  snd_cnt;				/* engine scratch: bytes per copy */
int  snd_drain;				/* end-of-stream drain countdown (2 -> 0) */
int  snd_done;				/* IRQ sets 1 when the stream has finished */
int  old_vec[2];			/* saved $E1002C firmware sound vector */

/* streamed-stereo state (M6): two rate-locked sample voices + one timer.  The
 * right channel gets its own pool pointer and DOC double-buffer; the IRQ refills
 * both L and R per fire. */
unsigned long snd_pool_ptr_r;		/* right-channel pool read pointer (24-bit) */
int  snd_stereo;			/* 1 = streamed stereo (two voices) */
int  snd_dst_pg_r;			/* engine scratch: right refill target page */
int  snd_timer_osc;			/* oscillator that is the refill timer (IRQ source) */

/* stdin-ring state (M4): a 64 KB ring of 256-byte pages the foreground fills
 * from stdin (producer) and the IRQ drains to the DOC (consumer).  ring_wr_pg
 * has one writer (C), ring_rd_pg one writer (the IRQ); 16-bit accesses are
 * atomic across the IRQ, so no lock is needed. */
int  snd_ring;				/* 1 = stdin ring mode (else linear pool) */
unsigned long snd_ring_base;		/* 64 KB ring base (24-bit) */
int  ring_rd_pg;			/* IRQ consume page index (0-255, wraps) */
int  ring_wr_pg;			/* foreground produce page index (0-255) */
int  snd_input_done;			/* foreground: stdin reached EOF */
int  snd_underruns;			/* diag: ring-empty refills (producer behind) */

/* libc (toolchain/include/fgx.h) -- declared here to keep this TU's includes
 * to the standard headers, as frotz's fgxmem.c does. */
extern long mm_alloc(unsigned long size, unsigned long *base);
extern int  mm_free(long handle);

/* ---- companion-asm entry points (ensoniqplay_stubs.s) ---- */
void eng_sound_claim();		/* SYS_SOUND_CLAIM: kernel silences DOC on kill */
void eng_doc_bringup();		/* halt all oscs, zero vols, drain IRQ, enable 32 */
void eng_doc_ram_addr();	/* placed: select DOC RAM autoinc at page snd_page */
void eng_doc_write_chunk();	/* placed: snd_buf -> DOC RAM, $00 -> $01 */
void eng_doc_stopper();		/* placed: write one $00 byte (one-shot end marker) */
void eng_osc_start();		/* placed: program + start oscillator 0 */
int  eng_osc_halted();		/* placed: 1 if oscillator 0 has halted */
void eng_osc_start_r();		/* placed stereo: program + start oscillator 1 (right) */
int  eng_osc_halted_r();	/* placed stereo: 1 if oscillator 1 has halted */
void eng_doc_halt();		/* halt all oscs + zero vols (teardown) */
int  eng_ticks();		/* low 16 bits of the 60 Hz system tick counter */
void eng_sleep1();		/* block one 60 Hz tick */
void eng_stream_prime();	/* streamed: prime buffer, program oscs, arm the IRQ */
void eng_stream_prime_stereo();	/* streamed stereo: two voices + timer */
void eng_stream_stop();		/* streamed: SEI, halt oscs, drain, restore vector */
void eng_ring_write();		/* stdin: fast copy snd_buf -> ring page ring_wr_pg */

static FILE *fp;

/* ---- source format + the streaming cook (input -> DOC-native 8-bit unsigned) */
static int fmt_bits;		/* 8 or 16 */
static int fmt_chans;		/* 1 or 2 */
static int fmt_signed;		/* input samples are two's-complement */
static int fmt_decim;		/* input frames averaged per output sample (>=1) */
static int fmt_bigendian;	/* 16-bit samples are big-endian (AU) */
static int fmt_ulaw;		/* 8-bit samples are mu-law encoded (AU) */

/* mu-law byte -> signed sample centred on 0 in -128..127 (the cook's common
 * form).  Generated by the standard G.711 mu-law expansion, scaled to 8-bit. */
static const int ulaw_c8[256] = {
	-125, -121, -117, -113, -109, -105, -101, -97, -93, -89, -85, -81, -77, -73, -69, -65,
	-62, -60, -58, -56, -54, -52, -50, -48, -46, -44, -42, -40, -38, -36, -34, -32,
	-31, -30, -29, -28, -27, -26, -25, -24, -23, -22, -21, -20, -19, -18, -17, -16,
	-15, -15, -14, -14, -13, -13, -12, -12, -11, -11, -10, -10, -9, -9, -8, -8,
	-7, -7, -7, -7, -6, -6, -6, -6, -5, -5, -5, -5, -4, -4, -4, -4,
	-3, -3, -3, -3, -3, -3, -3, -3, -2, -2, -2, -2, -2, -2, -2, -2,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	125, 121, 117, 113, 109, 105, 101, 97, 93, 89, 85, 81, 77, 73, 69, 65,
	62, 60, 58, 56, 54, 52, 50, 48, 46, 44, 42, 40, 38, 36, 34, 32,
	31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16,
	15, 15, 14, 14, 13, 13, 12, 12, 11, 11, 10, 10, 9, 9, 8, 8,
	7, 7, 7, 7, 6, 6, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4,
	3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};
static int fmt_stereo;		/* 1 = play as stereo (L on DOC ch0, R on ch1) */
static int ck_pick;		/* cook: -1 mix channels, 0 = left only, 1 = right only */
static int fmt_identity;	/* 1 = DOC-native already (raw 8-bit unsigned mono,
				 * no decim): skip the per-byte cook for the stdin
				 * producer, which must sustain the play rate */

static unsigned char ck_in[2048];	/* raw input buffer for the cook */
static int  ck_pos, ck_len;		/* consumed / filled within ck_in */
static long ck_remain;			/* input data bytes still to read (bounded) */
static int  ck_unbounded;		/* 1 = read until EOF (stdin); ignore ck_remain */
static long ck_data_off;		/* file offset of the data region (for rewind) */
static long ck_data_bytes;		/* data region length (for rewind) */

/* next raw input byte, or -1 at end of the data region / stdin. */
static int ck_getbyte()
{
	int n;

	if (ck_pos >= ck_len) {
		n = (int)sizeof(ck_in);
		if (!ck_unbounded) {
			if ((long)n > ck_remain)
				n = (int)ck_remain;
			if (n <= 0)
				return -1;	/* consumed the whole data region */
		}
		ck_len = (int)fread(ck_in, 1, n, fp);
		ck_pos = 0;
		if (ck_len <= 0)
			return -1;		/* EOF */
		if (!ck_unbounded)
			ck_remain = ck_remain - ck_len;
	}
	return ck_in[ck_pos++];
}

/* Read one input frame (all channels) and return its value as a signed sample
 * centred on 0 in -128..127, mixed to mono; CK_EOF at end of data. */
static int cook_frame()
{
	int c, lo, hi, s, acc;

	int chv[2];

	acc = 0;
	for (c = 0; c < fmt_chans; c++) {
		if (fmt_ulaw) {
			lo = ck_getbyte();
			if (lo < 0)
				return CK_EOF;
			s = ulaw_c8[lo];		/* already centred -128..127 */
		} else if (fmt_bits == 16) {
			lo = ck_getbyte();		/* first byte */
			hi = ck_getbyte();		/* second byte */
			if (lo < 0 || hi < 0)
				return CK_EOF;
			if (fmt_bigendian)
				s = hi | (lo << 8);	/* AU: first byte is high */
			else
				s = lo | (hi << 8);	/* WAV: first byte is low */
			if (s >= 32768)
				s = s - 65536;		/* signed 16-bit */
			s = s / 256;			/* -> -128..127 */
		} else {
			lo = ck_getbyte();
			if (lo < 0)
				return CK_EOF;
			if (fmt_signed)
				s = (lo < 128) ? lo : lo - 256;
			else
				s = lo - 128;
		}
		chv[c] = s;
		acc = acc + s;
	}
	if (ck_pick >= 0 && ck_pick < fmt_chans)
		return chv[ck_pick];		/* one channel (stereo L or R) */
	return acc / fmt_chans;			/* mix to mono */
}

/* Fill out[0..want-1] with cooked DOC-native bytes (8-bit unsigned, $80 =
 * silence), decimating fmt_decim input frames into each.  Returns the count
 * produced (< want at end of data). */
static int cook_read(out, want)
unsigned char *out;
int want;
{
	int n, d, fv, sum, cnt;

	n = 0;
	while (n < want) {
		sum = 0;
		cnt = 0;
		for (d = 0; d < fmt_decim; d++) {
			fv = cook_frame();
			if (fv == CK_EOF)
				break;
			sum = sum + fv;
			cnt++;
		}
		if (cnt == 0)
			break;			/* end of data */
		fv = sum / cnt + 128;		/* average -> unsigned byte */
		if (fv < 0)
			fv = 0;
		if (fv > 255)
			fv = 255;
		out[n++] = (unsigned char)fv;
	}
	return n;
}

/* Autodetect raw 8-bit signedness by histogram mode: real audio's most common
 * value is its quiet level -- 128 for unsigned, 0/255 for signed.  Samples up
 * to 64 KB, then rewinds.  1 = signed, 0 = unsigned. */
static int detect_signed(datalen)
long datalen;
{
	int  hist[256], j, n, mode, modecount, v;
	long total, save, i;

	for (i = 0; i < 256; i++)
		hist[i] = 0;
	save = ftell(fp);
	total = 0;
	while (total < datalen && total < 65536L) {
		n = (int)fread(snd_buf, 1, UPBUF_SZ, fp);
		if (n <= 0)
			break;
		for (j = 0; j < n; j++)
			hist[snd_buf[j]]++;
		total = total + n;
	}
	fseek(fp, save, SEEK_SET);
	mode = 128;
	modecount = -1;
	for (i = 0; i < 256; i++) {
		if (hist[i] > modecount) {
			modecount = hist[i];
			mode = (int)i;
		}
	}
	v = mode - 128;
	if (v < 0)
		v = -v;
	return (v >= 64) ? 1 : 0;	/* mode near a code edge => signed */
}

/* Parse a WAV header: on success position fp at the data chunk, set the fmt_*
 * fields (except decim), and return the sample rate and data byte count via the
 * out params.  Returns 1 on a supported file, 0 otherwise. */
static int parse_wav(rate_out, data_out)
long *rate_out, *data_out;
{
	unsigned char h[12], ch[8], f[16];
	long sz, sr;
	int  afmt, chans, bits;

	fseek(fp, 0L, SEEK_SET);
	if (fread(h, 1, 12, fp) != 12)
		return 0;
	if (h[0] != 'R' || h[1] != 'I' || h[2] != 'F' || h[3] != 'F')
		return 0;
	if (h[8] != 'W' || h[9] != 'A' || h[10] != 'V' || h[11] != 'E')
		return 0;

	afmt = 0; chans = 0; bits = 0; sr = 0;
	for (;;) {
		if (fread(ch, 1, 8, fp) != 8)
			return 0;
		sz = (long)ch[4] | ((long)ch[5] << 8) |
		     ((long)ch[6] << 16) | ((long)ch[7] << 24);
		if (ch[0] == 'f' && ch[1] == 'm' && ch[2] == 't' && ch[3] == ' ') {
			if (sz < 16 || fread(f, 1, 16, fp) != 16)
				return 0;
			afmt  = f[0] | (f[1] << 8);
			chans = f[2] | (f[3] << 8);
			sr    = (long)f[4] | ((long)f[5] << 8) |
				((long)f[6] << 16) | ((long)f[7] << 24);
			bits  = f[14] | (f[15] << 8);
			if (sz > 16)
				fseek(fp, sz - 16, SEEK_CUR);	/* skip extra fmt */
			if (sz & 1)
				fseek(fp, 1L, SEEK_CUR);	/* word alignment */
		} else if (ch[0] == 'd' && ch[1] == 'a' && ch[2] == 't' &&
			   ch[3] == 'a') {
			if (afmt != 1 || (bits != 8 && bits != 16) ||
			    chans < 1 || chans > 2 || sr <= 0)
				return 0;		/* unsupported encoding */
			fmt_chans  = chans;
			fmt_bits   = bits;
			fmt_signed = (bits == 16) ? 1 : 0;	/* WAV convention */
			*rate_out  = sr;
			*data_out  = sz;
			return 1;			/* fp is at the data bytes */
		} else {
			fseek(fp, sz + (sz & 1), SEEK_CUR);	/* skip unknown */
		}
	}
}

/* Parse a Sun/NeXT AU header (".snd", big-endian).  On success position fp at
 * the data, set the fmt_* fields, and return sample rate + data byte count.
 * Supports 8-bit mu-law (enc 1), 8-bit signed linear (enc 2), and 16-bit signed
 * linear (enc 3, big-endian).  Returns 1 on a supported file, 0 otherwise. */
static int parse_au(rate_out, data_out)
long *rate_out, *data_out;
{
	unsigned char h[24];
	long off, sz, enc, sr, ch, end;

	fseek(fp, 0L, SEEK_SET);
	if (fread(h, 1, 24, fp) != 24)
		return 0;
	if (h[0] != 0x2E || h[1] != 's' || h[2] != 'n' || h[3] != 'd')
		return 0;			/* not ".snd" */
	off = ((long)h[4] << 24) | ((long)h[5] << 16) | ((long)h[6] << 8) | h[7];
	sz  = ((long)h[8] << 24) | ((long)h[9] << 16) | ((long)h[10] << 8) | h[11];
	enc = ((long)h[12] << 24) | ((long)h[13] << 16) | ((long)h[14] << 8) | h[15];
	sr  = ((long)h[16] << 24) | ((long)h[17] << 16) | ((long)h[18] << 8) | h[19];
	ch  = ((long)h[20] << 24) | ((long)h[21] << 16) | ((long)h[22] << 8) | h[23];
	if (ch < 1 || ch > 2 || sr <= 0)
		return 0;

	fmt_chans = (int)ch;
	fmt_bigendian = 1;
	fmt_ulaw = 0;
	if (enc == 1) {
		fmt_ulaw = 1; fmt_bits = 8; fmt_signed = 1;	/* mu-law */
	} else if (enc == 2) {
		fmt_bits = 8; fmt_signed = 1;			/* 8-bit signed */
	} else if (enc == 3) {
		fmt_bits = 16; fmt_signed = 1;			/* 16-bit signed BE */
	} else {
		return 0;			/* unsupported encoding */
	}

	if (off < 24)
		off = 24;
	fseek(fp, 0L, SEEK_END);
	end = ftell(fp);
	if (sz <= 0 || off + sz > end)		/* size 0 / 0xFFFFFFFF / lying header */
		sz = end - off;
	fseek(fp, off, SEEK_SET);
	*rate_out = sr;
	*data_out = sz;
	return 1;
}

/* MILESTONE 1: upload the whole (<= 32 KB) cooked sample into DOC RAM and
 * one-shot it. */
static int play_placed(freq, rate, samples)
long freq, samples;
int rate;
{
	long total, expect, cap, elapsed, t0, n;
	int  halted;

	eng_sound_claim();
	eng_doc_bringup();

	snd_page = 0;
	eng_doc_ram_addr();
	total = 0;
	while (total < samples) {
		snd_chunk = cook_read(snd_buf, UPBUF_SZ);
		if (snd_chunk <= 0)
			break;
		eng_doc_write_chunk();		/* clamps interior $00 -> $01 */
		total = total + snd_chunk;
	}
	if (total == 0) {
		fprintf(stderr, "ensoniqplay: no samples\n");
		eng_doc_halt();
		return 1;
	}
	if (total < MAX_PLACED)
		eng_doc_stopper();		/* $00 halts the one-shot at the end */

	printf("ensoniqplay: %ld bytes @ %d Hz (freq %ld), playing\n",
	       total, rate, freq);

	snd_freq = (int)freq;
	snd_size = OSC_SIZE_32K;
	snd_vol  = 0xFF;
	snd_ctl  = OSC_CTL_ONESHOT;	/* oscillator 0, DOC channel 0 */
	eng_osc_start();

	expect = (total * 60L) / rate;
	cap = expect * 2L + 60L;
	t0 = eng_ticks();
	halted = 0;
	for (n = 0; n < cap; n++) {
		if (eng_osc_halted()) {
			halted = 1;
			break;
		}
		eng_sleep1();
	}
	elapsed = eng_ticks() - t0;
	if (elapsed < 0)
		elapsed = elapsed + 65536L;

	eng_doc_halt();
	printf("ensoniqplay: %s after %ld ticks (expected ~%ld)\n",
	       halted ? "halted" : "timed out", elapsed, expect);
	return 0;
}

/* Placed STEREO: upload the left channel to DOC RAM $0000 and the right to
 * $8000, then play them on oscillator 0 (DOC channel 0 = left) and oscillator 1
 * (channel 1 = right), both one-shot.  Each channel is <= 32 KB (one wavetable).
 * On mono-output hardware the two channels sum to the mono mix; on stereo
 * hardware (and this emulator) they separate into left/right. */
static int play_placed_stereo(freq, rate, samples)
long freq, samples;
int rate;
{
	long total, expect, cap, elapsed, t0, n;
	int  chan, halted;

	eng_sound_claim();
	eng_doc_bringup();

	for (chan = 0; chan < 2; chan++) {
		ck_pick = chan;			/* 0 = left, 1 = right */
		fseek(fp, ck_data_off, SEEK_SET);
		ck_remain = ck_data_bytes;
		ck_pos = 0;
		ck_len = 0;
		snd_page = chan ? 0x80 : 0x00;	/* left @ $0000, right @ $8000 */
		eng_doc_ram_addr();
		total = 0;
		while (total < samples) {
			snd_chunk = cook_read(snd_buf, UPBUF_SZ);
			if (snd_chunk <= 0)
				break;
			eng_doc_write_chunk();
			total = total + snd_chunk;
		}
		if (total < MAX_PLACED)
			eng_doc_stopper();
	}

	printf("ensoniqplay: %ld samples/ch @ %d Hz (freq %ld), stereo\n",
	       samples, rate, freq);

	snd_freq = (int)freq;
	snd_size = OSC_SIZE_32K;
	snd_vol  = 0xFF;
	snd_page = 0x00;
	snd_ctl  = OSC_CTL_ONESHOT;		/* osc 0 -> DOC channel 0 (left) */
	eng_osc_start();
	snd_page = 0x80;
	snd_ctl  = OSC_CTL_ONESHOT | 0x10;	/* osc 1 -> DOC channel 1 (right) */
	eng_osc_start_r();

	expect = (samples * 60L) / rate;
	cap = expect * 2L + 60L;
	t0 = eng_ticks();
	halted = 0;
	for (n = 0; n < cap; n++) {
		if (eng_osc_halted() && eng_osc_halted_r()) {
			halted = 1;
			break;
		}
		eng_sleep1();
	}
	elapsed = eng_ticks() - t0;
	if (elapsed < 0)
		elapsed = elapsed + 65536L;
	eng_doc_halt();
	printf("ensoniqplay: %s after %ld ticks (expected ~%ld)\n",
	       halted ? "halted" : "timed out", elapsed, expect);
	return 0;
}

/* MILESTONE 2: hold the whole cooked sample resident and stream it to the DOC
 * under the sound IRQ (double-buffer + rate-locked timer oscillator). */
static int play_stream(freq, rate, samples)
long freq, samples;
int rate;
{
	long poolsize, expect, cap, elapsed, t0, n, handle, rem;
	unsigned long dst, poolend;
	int  i, got, want;

	/* Pool = samples rounded up to a 256 B refill half, tail padded silent. */
	poolsize = (samples + 255L) & ~255L;
	snd_pool_base = 0;
	handle = mm_alloc((unsigned long)poolsize, &snd_pool_base);
	if (handle == 0 || snd_pool_base == 0) {
		fprintf(stderr, "ensoniqplay: out of memory for %ld-byte pool\n",
			poolsize);
		return 1;
	}

	/* Load the file into the pool.  The (unsigned char *)(long) store/read
	 * carries all 24 bits, so a >64 KB pool is written straight through (the
	 * frotz far pattern).  For a DOC-native (identity) source, fread reads the
	 * data directly into the pool -- no per-byte cook, no per-byte far store,
	 * which matters for a multi-megabyte clip.  Otherwise cook + far-store. */
	dst = snd_pool_base;
	poolend = snd_pool_base + poolsize;
	if (fmt_identity) {
		rem = samples;			/* identity: samples == data bytes */
		while (rem > 0) {
			want = (rem < (long)UPBUF_SZ) ? (int)rem : UPBUF_SZ;
			got = (int)fread((unsigned char *)dst, 1, want, fp);
			if (got <= 0)
				break;
			dst = dst + got;
			rem = rem - got;
		}
	} else {
		for (;;) {
			got = cook_read(snd_buf, UPBUF_SZ);
			if (got <= 0)
				break;
			for (i = 0; i < got; i++)
				*(unsigned char *)(dst + i) = snd_buf[i];
			dst = dst + got;
		}
	}
	while (dst < poolend) {			/* pad the final half to silence */
		*(unsigned char *)dst = 0x80;
		dst = dst + 1;
	}

	snd_ring = 0;			/* linear pool, not the stdin ring */
	snd_stereo = 0;
	snd_pool_ptr = snd_pool_base;
	snd_pool_end = poolend;
	snd_pg_off = 0;
	snd_dst_pg = 0;
	snd_cnt = 0;
	snd_drain = 0;
	snd_done = 0;
	snd_freq = (int)freq;
	snd_vol  = 0xFF;

	eng_sound_claim();
	eng_doc_bringup();
	eng_stream_prime();		/* consumes the first 512 B, starts both oscs */

	printf("ensoniqplay: %ld bytes @ %d Hz (freq %ld), streaming\n",
	       samples, rate, freq);

	expect = (samples * 60L) / rate;
	cap = expect * 2L + 120L;
	t0 = eng_ticks();
	for (n = 0; n < cap; n++) {
		if (snd_done)
			break;
		eng_sleep1();
	}
	elapsed = eng_ticks() - t0;
	if (elapsed < 0)
		elapsed = elapsed + 65536L;

	eng_stream_stop();
	mm_free(handle);		/* MM blocks are kernel resources, not auto-freed */

	printf("ensoniqplay: %s after %ld ticks (expected ~%ld)\n",
	       snd_done ? "finished" : "timed out", elapsed, expect);
	return 0;
}

/* MILESTONE 6: streamed STEREO.  De-interleave the file into left and right
 * halves of one pool, then stream both under the sound IRQ -- oscillator 0
 * plays the left double-buffer on DOC channel 0, oscillator 1 the right on
 * channel 1, and the silent timer (oscillator 2) drives refills of both.  Two
 * cook passes (left, then right) load the pool. */
static int play_stream_stereo(freq, rate, samples)
long freq, samples;
int rate;
{
	long poolsize, expect, cap, elapsed, t0, n, handle;
	unsigned long baseL, baseR, dst, endp;
	int chan, got, i;

	poolsize = (samples + 255L) & ~255L;		/* per channel */
	snd_pool_base = 0;
	handle = mm_alloc((unsigned long)(poolsize * 2L), &snd_pool_base);
	if (handle == 0 || snd_pool_base == 0) {
		fprintf(stderr, "ensoniqplay: out of memory for %ld-byte stereo pool\n",
			poolsize * 2L);
		return 1;
	}
	baseL = snd_pool_base;
	baseR = snd_pool_base + poolsize;

	/* De-interleave: pass 0 -> left half of the pool, pass 1 -> right half. */
	for (chan = 0; chan < 2; chan++) {
		ck_pick = chan;
		fseek(fp, ck_data_off, SEEK_SET);
		ck_remain = ck_data_bytes;
		ck_pos = 0;
		ck_len = 0;
		dst = chan ? baseR : baseL;
		endp = dst + poolsize;
		for (;;) {
			got = cook_read(snd_buf, UPBUF_SZ);
			if (got <= 0)
				break;
			for (i = 0; i < got; i++)
				*(unsigned char *)(dst + i) = snd_buf[i];
			dst = dst + got;
		}
		while (dst < endp) {
			*(unsigned char *)dst = 0x80;
			dst = dst + 1;
		}
	}

	snd_ring = 0;
	snd_pool_ptr = baseL;
	snd_pool_ptr_r = baseR;
	snd_pool_end = baseL + poolsize;	/* left end; right is the same length */
	snd_pg_off = 0;
	snd_dst_pg = 0;
	snd_dst_pg_r = 0;
	snd_cnt = 0;
	snd_drain = 0;
	snd_done = 0;
	snd_freq = (int)freq;
	snd_vol = 0xFF;

	eng_sound_claim();
	eng_doc_bringup();
	eng_stream_prime_stereo();

	printf("ensoniqplay: %ld samples/ch @ %d Hz (freq %ld), streaming stereo\n",
	       samples, rate, freq);

	expect = (samples * 60L) / rate;
	cap = expect * 2L + 120L;
	t0 = eng_ticks();
	for (n = 0; n < cap; n++) {
		if (snd_done)
			break;
		eng_sleep1();
	}
	elapsed = eng_ticks() - t0;
	if (elapsed < 0)
		elapsed = elapsed + 65536L;

	eng_stream_stop();
	mm_free(handle);

	printf("ensoniqplay: %s after %ld ticks (expected ~%ld)\n",
	       snd_done ? "finished" : "timed out", elapsed, expect);
	return 0;
}

#define RING_PAGES	256	/* 64 KB ring / 256-byte pages (index wraps at 256) */
#define RING_MAX	254	/* leave >=1 empty slot so wr never overtakes rd */
#define PREFILL_PAGES	64	/* build a cushion (~0.75 s) before starting */

/* Cook one 256-byte page from stdin into ring page ring_wr_pg; return 0 at end
 * of stdin.  Caller guarantees the ring has room. */
static int produce_page()
{
	int got, i;

	if (fmt_identity)
		got = (int)fread(snd_buf, 1, 256, fp);	/* raw = DOC-native: no cook */
	else
		got = cook_read(snd_buf, 256);
	if (got <= 0)
		return 0;			/* EOF */
	for (i = got; i < 256; i++)
		snd_buf[i] = 0x80;		/* pad a short final page with silence */
	eng_ring_write();			/* snd_buf -> ring page ring_wr_pg (fast) */
	ring_wr_pg = (ring_wr_pg + 1) & 0xFF;
	return 1;
}

/* MILESTONE 4: stream from stdin.  A 64 KB ring is filled from stdin by this
 * foreground loop while the sound IRQ drains it to the DOC double-buffer, so
 * playback starts after a small cushion and never needs the whole input in
 * memory.  stdin is raw 8-bit (it cannot be seeked, so no WAV parse / no
 * autodetect); rate is -r, signedness -s/-u (default unsigned). */
static int play_stdin(freq, rate)
long freq;
int rate;
{
	long handle, t0, elapsed, cap, n;
	int eof, ct, i;

	handle = mm_alloc(0x10000L, &snd_ring_base);	/* 64 KB ring */
	if (handle == 0 || snd_ring_base == 0) {
		fprintf(stderr, "ensoniqplay: out of memory for stdin ring\n");
		return 1;
	}
	snd_ring = 1;
	snd_stereo = 0;
	ring_rd_pg = 0;
	ring_wr_pg = 0;
	snd_input_done = 0;
	snd_underruns = 0;

	/* Prefill a cushion (or until EOF). */
	eof = 0;
	while (!eof) {
		ct = (ring_wr_pg - ring_rd_pg) & 0xFF;
		if (ct >= PREFILL_PAGES)
			break;
		if (!produce_page())
			eof = 1;
	}
	/* The prime consumes 2 pages; pad with silence if stdin was tiny. */
	while (((ring_wr_pg - ring_rd_pg) & 0xFF) < 2) {
		for (i = 0; i < 256; i++)
			snd_buf[i] = 0x80;
		eng_ring_write();
		ring_wr_pg = (ring_wr_pg + 1) & 0xFF;
	}

	snd_pool_ptr = snd_ring_base;		/* prime copies ring pages 0,1 */
	snd_freq = (int)freq;
	snd_vol  = 0xFF;
	snd_pg_off = 0;
	snd_dst_pg = 0;
	snd_cnt = 0;
	snd_drain = 0;
	snd_done = 0;

	eng_sound_claim();
	eng_doc_bringup();
	eng_stream_prime();
	ring_rd_pg = 2;				/* prime consumed pages 0,1 */

	printf("ensoniqplay: streaming from stdin @ %d Hz (freq %ld)\n",
	       rate, freq);

	t0 = eng_ticks();
	/* Keep the ring fed until stdin ends (or the IRQ engine stops us). */
	while (!eof && !snd_done) {
		ct = (ring_wr_pg - ring_rd_pg) & 0xFF;
		if (ct >= RING_MAX)
			eng_sleep1();		/* ring full: let the IRQ drain it */
		else if (!produce_page())
			eof = 1;
	}
	snd_input_done = 1;			/* no more data: IRQ drains + halts */

	/* Wait for the consumer to empty the ring and finish, capped. */
	cap = 1200L;
	for (n = 0; n < cap; n++) {
		if (snd_done)
			break;
		eng_sleep1();
	}
	elapsed = eng_ticks() - t0;
	if (elapsed < 0)
		elapsed = elapsed + 65536L;

	eng_stream_stop();
	mm_free(handle);

	printf("ensoniqplay: %s after %ld ticks, %d underruns\n",
	       snd_done ? "finished" : "timed out", elapsed, snd_underruns);
	return 0;
}

int main(argc, argv)
int argc;
char **argv;
{
	char *path, *o;
	int   rate, srate_i, i, rc, force_sign, detect, force_mono;
	long  freq, filesize, srcrate, databytes, frames, samples, effrate;
	long  bytes_per_frame;

	rate = 22050;			/* raw default rate */
	force_sign = -1;		/* -1 none, 0 unsigned, 1 signed (raw) */
	detect = 0;			/* -a: autodetect raw signedness */
	force_mono = 0;			/* -m: force stereo down-mix to mono */
	path = (char *)0;
	for (i = 1; i < argc; i++) {
		if (argv[i][0] == '-' && argv[i][1] != 0) {	/* a flag, not lone '-' */
			o = argv[i] + 1;
			if (*o == 'r' && i + 1 < argc) {
				rate = atoi(argv[++i]);
			} else {
				while (*o) {
					if (*o == 's')      force_sign = 1;
					else if (*o == 'u') force_sign = 0;
					else if (*o == 'a') detect = 1;
					else if (*o == 'm') force_mono = 1;
					o++;
				}
			}
		} else if (path == (char *)0) {
			path = argv[i];
		}
	}
	if (path == (char *)0) {
		fprintf(stderr, "usage: ensoniqplay [-r rate] [-s|-u|-a] file|-\n");
		fprintf(stderr, "  WAV (8/16-bit, mono/stereo) or raw 8-bit PCM;\n");
		fprintf(stderr, "  '-' streams raw 8-bit from stdin.\n");
		fprintf(stderr, "  raw: -r sets the rate; signedness defaults to\n");
		fprintf(stderr, "  unsigned (-u), -s forces signed, -a autodetects.\n");
		return 1;
	}

	/* stdin: raw 8-bit, unbounded, streamed through the ring (no seek, so no
	 * WAV parse and no -a autodetect). */
	if (path[0] == '-' && path[1] == 0) {
		fp = stdin;
		fmt_bits = 8;
		fmt_chans = 1;
		fmt_signed = (force_sign >= 0) ? force_sign : 0;
		ck_unbounded = 1;
		ck_pos = 0;
		ck_len = 0;
		srcrate = rate;
		fmt_decim = (int)((srcrate + DOC_SCAN_RATE - 1L) / DOC_SCAN_RATE);
		if (fmt_decim < 1)
			fmt_decim = 1;
		effrate = srcrate / fmt_decim;
		if (effrate < 1000)
			effrate = 1000;
		srate_i = (int)effrate;
		freq = ((long)effrate * 512L + DOC_SCAN_RATE / 2L) / DOC_SCAN_RATE;
		if (freq < 1)
			freq = 1;
		if (freq > 512)
			freq = 512;
		/* raw 8-bit unsigned mono with no decimation is already DOC-native:
		 * let the producer skip the per-byte cook so it can sustain rate. */
		fmt_identity = (fmt_signed == 0 && fmt_decim == 1);
		printf("ensoniqplay: stdin, raw 8-bit %s mono %ld Hz\n",
		       fmt_signed ? "signed" : "unsigned", srcrate);
		if (fmt_decim > 1)
			printf("ensoniqplay: decimated %ld -> %ld Hz (/%d)\n",
			       srcrate, effrate, fmt_decim);
		return play_stdin(freq, srate_i);
	}

	fp = fopen(path, "r");
	if (fp == (FILE *)0) {
		fprintf(stderr, "ensoniqplay: cannot open %s\n", path);
		return 1;
	}
	fseek(fp, 0L, SEEK_END);
	filesize = ftell(fp);
	fseek(fp, 0L, SEEK_SET);
	if (filesize <= 0) {
		fprintf(stderr, "ensoniqplay: empty file\n");
		fclose(fp);
		return 1;
	}

	if (parse_wav(&srcrate, &databytes)) {
		printf("ensoniqplay: wav %d-bit %s %s %ld Hz\n",
		       fmt_bits, fmt_signed ? "signed" : "unsigned",
		       (fmt_chans == 2) ? "stereo" : "mono", srcrate);
	} else if (parse_au(&srcrate, &databytes)) {
		printf("ensoniqplay: au %s %s %ld Hz\n",
		       fmt_ulaw ? "mu-law" :
		       (fmt_bits == 16 ? "16-bit signed" : "8-bit signed"),
		       (fmt_chans == 2) ? "stereo" : "mono", srcrate);
	} else {
		/* raw 8-bit mono */
		fseek(fp, 0L, SEEK_SET);
		fmt_bits = 8;
		fmt_chans = 1;
		fmt_bigendian = 0;
		fmt_ulaw = 0;
		srcrate = rate;
		databytes = filesize;
		if (force_sign >= 0)
			fmt_signed = force_sign;
		else if (detect)
			fmt_signed = detect_signed(databytes);
		else
			fmt_signed = 0;			/* default: unsigned */
		printf("ensoniqplay: raw 8-bit %s mono %ld Hz%s\n",
		       fmt_signed ? "signed" : "unsigned", srcrate,
		       (force_sign < 0 && detect) ? " (detected)" : "");
	}

	/* Decimate a too-fast source down to the DOC ceiling, keeping pitch. */
	fmt_decim = (int)((srcrate + DOC_SCAN_RATE - 1L) / DOC_SCAN_RATE);
	if (fmt_decim < 1)
		fmt_decim = 1;
	effrate = srcrate / fmt_decim;
	if (effrate < 1000)
		effrate = 1000;
	srate_i = (int)effrate;
	freq = ((long)effrate * 512L + DOC_SCAN_RATE / 2L) / DOC_SCAN_RATE;
	if (freq < 1)
		freq = 1;
	if (freq > 512)
		freq = 512;

	bytes_per_frame = (long)(fmt_bits / 8) * fmt_chans;
	frames = databytes / bytes_per_frame;
	samples = frames / fmt_decim;
	if (fmt_decim > 1)
		printf("ensoniqplay: decimated %ld -> %ld Hz (/%d)\n",
		       srcrate, effrate, fmt_decim);
	/* Raw/WAV/AU that is already DOC-native (8-bit unsigned mono, no decimation)
	 * needs no per-byte cook -- the loaders bulk-read it.  For these, samples
	 * equals the data byte count. */
	fmt_identity = (fmt_bits == 8 && fmt_chans == 1 && fmt_signed == 0 &&
			!fmt_ulaw && fmt_decim == 1);
	if (samples <= 0) {
		fprintf(stderr, "ensoniqplay: no samples\n");
		fclose(fp);
		return 1;
	}

	/* fp is at the data start (parse_wav positioned it; raw is at 0); arm the
	 * cook to read exactly the data region. */
	ck_data_off = ftell(fp);	/* remember the data start for stereo's 2 passes */
	ck_data_bytes = databytes;
	ck_remain = databytes;
	ck_pos = 0;
	ck_len = 0;
	ck_pick = -1;			/* default: mix channels to mono */
	fmt_stereo = (fmt_chans == 2 && !force_mono);

	if (fmt_stereo && samples <= MAX_PLACED)
		rc = play_placed_stereo(freq, srate_i, samples);
	else if (fmt_stereo)
		rc = play_stream_stereo(freq, srate_i, samples);
	else if (samples <= MAX_PLACED)
		rc = play_placed(freq, srate_i, samples);
	else
		rc = play_stream(freq, srate_i, samples);

	fclose(fp);
	return rc;
}
