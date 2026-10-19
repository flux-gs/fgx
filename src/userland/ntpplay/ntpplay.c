/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: FGX-original
 *   ntpplay - NinjaTracker+ (.ntp) MOD player.  C framework (this file) +
 *   companion asm engine (ntpplay_stubs.s).  The tracker engine runs at
 *   sound-IRQ time and stays asm; the load path + control flow live here in C.
 *   See docs/history/plans/2026-07-12-fgx-ntpplay-c-framework.md.  H3 final
 *   rung - retires the last hand-asm userland tool.
 *
 *   ABI: every variable the engine touches is a non-static C global (seg1);
 *   the engine reads/writes them by bare name, DBR-relative, via seg1_layout.s
 *   (DBR = data bank when C calls a companion entry, and the IRQ handler sets
 *   DBR = data bank from the seg0 saved-bank cell).  The DOC / Memory-Manager
 *   bit-banging is a handful of exported asm helpers (companion .s for
 *   the engine, not inline __asm) that pass values through these same globals.
 *
 * Format (all multi-byte fields little-endian; re/shellplay/PHASE_A_NOTES sec.1):
 *   magic "nfc!" (4)  version (1)  counts tracks,instr,pat,order,namelen (5)
 *   name <namelen>    tracks 3B x<tracks> (b0=stereo chan, b2=base osc)
 *   instrs 15B prefix x<instr> + <prefix[14]> name bytes; order <order> bytes;
 *   patterns <tracks>*256 B each; then sample data.
 *
 * INCREMENT 2 (this file's current state): C load path proven end to end -
 *   parse -> resident MM pattern block -> stream pool -> DOC upload, via the
 *   asm helpers.  The play control loop + engine arrive in increment 3.
 */
#include <stdio.h>
#include "ntpplay_tables.h"

#define MAX_INS		32	/* ProTracker <=31 instruments */
#define MAX_TRACKS	16	/* ProTracker <=9 tracks */
#define NUM_OSC		32	/* DOC oscillator count */
#define UPBUF_SZ	4096	/* disk-read + DOC/pool drain block */
#define STREAM_BUF_TOP	0xFC	/* track t stream buffer = pages (FC-t*2)/(+1) */
#define INSPECT_INS	3	/* -i: instrument# to audition solo (1-based) */
#define INSPECT_NOTE	37	/* -i: note index */

/* ---- file / parse scratch ---- */
long filepos;			/* 24-bit running file position (manual, mirrors addpos) */
long sampoff;			/* file offset of the sample-data tail */
int  patstep;			/* bytes per pattern = ntracks*256 */
int  patcount;			/* geometry loop counter */
unsigned char magicbuf[5];
unsigned char verbuf[2];
unsigned char cntbuf[6];
int  namelen;
unsigned char namebuf[64];
int  ntracks;
int  ninstr;
int  npat;
int  norder;
unsigned char trkbuf[4];
unsigned char insbuf[16];
int  skiplen;
unsigned char skipbuf[64];

/* ---- per-instrument arrays (indexed by instrument#, word stride) ---- */
int ins_type[MAX_INS];
int ins_len_lo[MAX_INS];
int ins_len_hi[MAX_INS];
int ins_vol[MAX_INS];
int ins_finetune[MAX_INS];
int ins_docptr[MAX_INS];
int ins_docsize[MAX_INS];
int ins_pooloff_lo[MAX_INS];	/* stream-pool byte offset (streamed instruments) */
int ins_pooloff_hi[MAX_INS];
int ins_rep_len_lo[MAX_INS];	/* loop length (bytes 7-9) */
int ins_rep_len_hi[MAX_INS];
int ins_rep_ptr_lo[MAX_INS];	/* loop start (bytes 4-6) */
int ins_rep_ptr_hi[MAX_INS];

/* ---- song structure ---- */
unsigned char orderbuf[256];
int  order0;
long patbase;			/* file offset of pattern region */
long patoff;			/* per-pattern file offset scratch */
long mm_handle;			/* resident-block MM handle (offset+bank) */
int  old_vec[2];		/* saved $E1002C vector (IRQ teardown) */
unsigned char osc_job_tbl[NUM_OSC];	/* per-osc IRQ job (JOB_*) */
int  irq_osc;			/* osc# of the IRQ being dispatched */
int  irq_ticks;			/* engine ticks since the song started */

/* ---- per-streamed-voice state (word stride, indexed by track) ---- */
int strm_ptr_lo[MAX_TRACKS];
int strm_ptr_hi[MAX_TRACKS];
int strm_end_lo[MAX_TRACKS];
int strm_end_hi[MAX_TRACKS];
int strm_replen_lo[MAX_TRACKS];
int strm_replen_hi[MAX_TRACKS];
int strm_looped[MAX_TRACKS];
int strm_base_pg[MAX_TRACKS];
int strm_pg_off[MAX_TRACKS];
unsigned char osc_strm_trk[NUM_OSC];	/* stream osc# -> owning track (for the IRQ) */
int strm_active;
int strm_dst_pg;
int strm_cnt;

/* ---- resident pattern block + stream pool (24-bit MM pointers) ---- */
long res_base;			/* resident block base */
long res_dst;			/* per-pattern copy dest */
int  res_ok;			/* 1 = patterns resident; 0 = disk */
int  ld_pat;			/* resident-load pattern counter */
long mm_size;			/* pattern-region size = npat*patstep */
long pool_handle;
long pool_base;
long pool_wr;			/* running pool write pointer */
long pool_size;
int  pool_ok;
int  ppidx;
unsigned char pattbuf[2304];	/* one pattern (ntracks*256, ntracks<=9) */
int track_osc[MAX_TRACKS];
int track_chan[MAX_TRACKS];

/* ---- current-note scratch (engine) ---- */
int cur_finetune, cur_ins, cur_type, cur_docptr, cur_docsize;
int cur_vol, cur_modvol, cur_osc, cur_chan, voc, wv_scaled;
int curfreq, nf_tmp;		/* note->freq scratch */
int row, patptr, rowstep, trkidx2, noteidx, insnum;
int last_ins[MAX_TRACKS];

/* ---- per-track effect / lifecycle state (engine) ---- */
int curr_vol[MAX_TRACKS];
int vol_delta[MAX_TRACKS];
int note_cut[MAX_TRACKS];
int note_delay[MAX_TRACKS];
int trk_nosc[MAX_TRACKS];
int curr_eff[MAX_TRACKS];
int curr_val[MAX_TRACKS];
int curr_ptr[MAX_TRACKS];
int slide_delta[MAX_TRACKS];
int slide_target[MAX_TRACKS];
int arp_phase[MAX_TRACKS];
int arp_ptr1[MAX_TRACKS];
int arp_ptr2[MAX_TRACKS];
int arp_ptr3[MAX_TRACKS];
int vibrato_voff[MAX_TRACKS];
int vibrato_rate[MAX_TRACKS];
int vibrato_pos[MAX_TRACKS];

/* ---- upload / playback control ---- */
int trigcnt;
int upidx;
int up_dotcnt;
int max_doc_page;
int up_write;			/* upload: nonzero doc_ptr = write to DOC RAM */
int songpos;
int cur_pat;
int master_vol;
long rem24;			/* upload bytes-remaining (24-bit) */
int chunk;
int fillcnt;
unsigned char upbuf[UPBUF_SZ];
long tbuf;
int tstart;

/* ---- flags + diag counters (the engine writes; C prints) ---- */
int g_check, g_trace, g_done, g_abort, g_inspect, g_autoquit;
int g_esc_state;	/* vt100 arrow CSI decode: 0 idle, 1 saw ESC, 2 saw ESC[ */
int d_cut, d_setv, d_vz, d_vsl, d_ndl;
int speed = 6;			/* ticks per row (dynamic from $0F) */
int ttick, effval_tmp, se_sub, se_n;
int pend_jump, pend_jump_param, start_row, sb_tmp;
int d_spd, d_pj, d_br;
int nf_ptr, wf_freq;
int d_su, d_sd, d_porta, d_arp, d_vib, d_c5, d_c6;

/* ---- companion-asm entry points (ntpplay_stubs.s) ---- */
/* load helpers: pass inputs/outputs through the globals above */
void eng_doc_bringup(void);	/* halt oscs, zero vols, drain, enable 31 */
int  eng_res_alloc(void);	/* mm_size -> res_base/mm_handle; 1 ok / 0 fail */
void eng_res_free(void);	/* SYS_MM_FREE(mm_handle) */
void eng_pat_to_res(void);	/* pattbuf[patstep] -> [res_dst] (cross-bank) */
int  eng_pool_alloc(void);	/* pool_size -> pool_base/pool_handle; 1 ok / 0 fail */
void eng_doc_addr(void);	/* select DOC RAM autoinc at page = up_write */
void eng_doc_write_chunk(void);	/* upbuf[0..chunk-1] -> DOC RAM (autoinc) */
void eng_pool_write_chunk(void);/* upbuf[0..chunk-1] -> [pool_wr]; pool_wr += chunk */
void eng_pool_free(void);	/* SYS_MM_FREE(pool_handle) */
void eng_doc_halt(void);	/* halt all oscs + zero vols (foreground teardown) */

/* engine entries (ntpplay_stubs.s): the tracker engine, DBR = data bank */
int  eng_load_pattern(void);	/* load pattern at songpos; 1 ok / 0 song-end */
void eng_do_one_tick(void);	/* advance the engine one tick (foreground path) */
void eng_irq_install(void);	/* arm osc-31 timer + $E1002C handler (engine-in-IRQ) */
void eng_irq_uninstall(void);	/* halt oscs + restore the vector */
void eng_poll_keyboard(void);	/* ^C/q/ESC -> g_abort; arrows -> master_vol */
void eng_wait_tick(void);	/* foreground pacing (no-op under -c) */
int  eng_wait_irq(void);	/* WAI + yield; returns the engine tick count */
void eng_inspect_run(void);	/* -i audition mode (currently a no-op) */

static FILE *fp;

/* read n bytes into b; advance the manual filepos; 1 = full read, 0 = short. */
static int rd(unsigned char *b, int n)
{
	if (fread(b, 1, n, fp) != n)
		return 0;
	filepos = filepos + n;
	return 1;
}

/* 24-bit sample length of instrument k (hi<<16 | lo), as a long.  Built byte by
 * byte: `int & 0xFFFF` OR'd into a long sign-extends for lengths >= 0x8000 (a
 * >32 KB sample), so mask each byte and shift a non-negative long instead. */
static long ins_len(int k)
{
	long v;
	v = ins_len_hi[k] & 0xFF;			/* byte 2 (bits 16-23) */
	v = (v << 8) | ((ins_len_lo[k] >> 8) & 0xFF);	/* byte 1 */
	v = (v << 8) | (ins_len_lo[k] & 0xFF);		/* byte 0 */
	return v;
}

/* print the effect-dispatch diagnostics (the -c oracle output); was print_diag. */
static void print_diag(void)
{
	printf("ntpplay: diag cut=%04X setv=%04X vz=%04X vsl=%04X ndl=%04X\n",
	       d_cut, d_setv, d_vz, d_vsl, d_ndl);
	printf(" spd=%04X pj=%04X br=%04X\n", d_spd, d_pj, d_br);
	printf(" su=%04X sd=%04X po=%04X arp=%04X vib=%04X c5=%04X c6=%04X\n",
	       d_su, d_sd, d_porta, d_arp, d_vib, d_c5, d_c6);
}

int main(int argc, char **argv)
{
	int i, k, t, endpg;
	long pool_off, inslen;
	char *o, *path;

	printf("\033[2J\033[H");			/* clear + home */

	g_check = g_trace = g_inspect = g_autoquit = 0;
	path = NULL;
	for (i = 1; i < argc; i++) {
		if (argv[i][0] == '-') {
			o = argv[i] + 1;
			while (*o) {
				if (*o == 'c')
					g_check = 1;
				else if (*o == 't')
					g_trace = 1;
				else if (*o == 'i')
					g_inspect = 1;
				else if (*o == 'Q')
					g_autoquit = 1;
				o++;
			}
		} else if (path == NULL) {
			path = argv[i];
		}
	}
	if (path == NULL) {
		printf("usage: ntpplay [-c] [-t] file\n");
		return 1;
	}

	fp = fopen(path, "r");
	if (fp == NULL) {
		printf("cannot open\n");
		return 1;
	}
	filepos = 0;

	/* ---- header ---- */
	if (!rd(magicbuf, 4))
		goto shorterr;
	if (magicbuf[0] != 'n' || magicbuf[1] != 'f' ||
	    magicbuf[2] != 'c' || magicbuf[3] != '!') {
		printf("bad magic\n");
		fclose(fp);
		return 1;
	}
	if (!rd(verbuf, 1) || !rd(cntbuf, 5))
		goto shorterr;
	ntracks = cntbuf[0];
	ninstr  = cntbuf[1];
	npat    = cntbuf[2];
	norder  = cntbuf[3];
	namelen = cntbuf[4];
	if (!rd(namebuf, namelen))
		goto shorterr;

	/* ---- track table: ntracks * 3 bytes ---- */
	for (t = 0; t < ntracks; t++) {
		if (!rd(trkbuf, 3))
			goto shorterr;
		if (t < MAX_TRACKS) {
			track_osc[t]  = trkbuf[2] & 0x1F;		/* base oscillator */
			track_chan[t] = (trkbuf[0] & 0x07) << 4;	/* channel -> ctl bits 4-6 */
		}
	}

	/* ---- instrument records: ninstr * (15 + name) ---- */
	for (k = 0; k < ninstr; k++) {
		if (!rd(insbuf, 15))
			goto shorterr;
		if (k < MAX_INS) {
			ins_type[k]       = insbuf[0];
			ins_len_lo[k]     = insbuf[1] | (insbuf[2] << 8);
			ins_len_hi[k]     = insbuf[3];
			ins_rep_ptr_lo[k] = insbuf[4] | (insbuf[5] << 8);
			ins_rep_ptr_hi[k] = insbuf[6];
			ins_rep_len_lo[k] = insbuf[7] | (insbuf[8] << 8);
			ins_rep_len_hi[k] = insbuf[9];
			ins_vol[k]        = insbuf[10];
			ins_finetune[k]   = insbuf[11];
			ins_docptr[k]     = insbuf[12];
			ins_docsize[k]    = insbuf[13];
		}
		skiplen = insbuf[14];
		if (skiplen && !rd(skipbuf, skiplen))
			goto shorterr;
	}

	/* ---- order table ---- */
	if (!rd(orderbuf, norder))
		goto shorterr;
	order0 = orderbuf[0];

	/* ---- geometry ---- */
	patstep = ntracks * 256;
	patbase = filepos;				/* pattern region begins here */
	mm_size = (long)npat * patstep;
	sampoff = patbase + mm_size;			/* sample data follows all patterns */
	printf("ntpplay: parsed\n");

	/* ==== resident pattern block: load every pattern into MM RAM so the IRQ
	 * engine reads patterns with no disk.  On any failure res_ok stays 0. ==== */
	res_ok = 0;
	if (npat > 0 && eng_res_alloc()) {
		res_ok = 1;
		for (ld_pat = 0; ld_pat < npat; ld_pat++) {
			patoff = patbase + (long)ld_pat * patstep;
			if (fseek(fp, patoff, SEEK_SET) != 0 ||
			    fread(pattbuf, 1, patstep, fp) != patstep) {
				eng_res_free();
				res_ok = 0;
				break;
			}
			res_dst = res_base + (long)ld_pat * patstep;
			eng_pat_to_res();
		}
		if (res_ok)
			printf("ntpplay: resident\n");
	} else if (npat > 0) {
		printf("ntpplay: mm ALLOC fail\n");
	}
	fseek(fp, sampoff, SEEK_SET);			/* rewind to the sample tail */

	if (g_check)
		goto loaded;				/* -c: no audio (skip DOC + upload) */

	/* ==== DOC bring-up ==== */
	eng_doc_bringup();

	/* ==== stream pool: make doc_ptr==0 instruments resident so the IRQ can
	 * refill the DOC from RAM.  size = sum of ins_len for streamed instrs. ==== */
	pool_ok = 0;
	pool_size = 0;
	for (k = 0; k < ninstr && k < MAX_INS; k++) {
		if ((ins_docptr[k] & 0xFF) != 0)
			continue;			/* placed in DOC RAM -> not streamed */
		ins_pooloff_lo[k] = (int)(pool_size & 0xFFFF);
		ins_pooloff_hi[k] = (int)((pool_size >> 16) & 0xFF);
		pool_size = pool_size + ins_len(k);
	}
	if (pool_size > 0 && eng_pool_alloc()) {
		pool_ok = 1;
		printf("ntpplay: pool\n");
	} else if (pool_size > 0) {
		printf("ntpplay: pool ALLOC fail\n");
	}

	/* ==== upload every instrument to its doc_ptr page (or the pool) ====
	 * pool_off is a running long byte-offset into the pool (streamed
	 * instruments, in file order — same order the sizing pass assigned).
	 * Computing pool_wr from a long accumulator avoids reconstructing it from
	 * the 16-bit ins_pooloff_lo, which sign-extends for offsets >= 0x8000
	 * (a multi-instrument pool >32 KB) and would produce a wild cross-bank
	 * write that corrupts the resident patterns. */
	max_doc_page = 0;
	pool_off = 0;
	for (upidx = 0; upidx < ninstr && upidx < MAX_INS; upidx++) {
		inslen = ins_len(upidx);
		rem24 = inslen;
		up_write = ins_docptr[upidx] & 0xFF;
		if (up_write == 0) {
			if (pool_ok)
				pool_wr = pool_base + pool_off;
			pool_off = pool_off + inslen;	/* next streamed instrument */
		} else {
			endpg = up_write + (int)(inslen >> 8);	/* collision guard */
			if (endpg > max_doc_page)
				max_doc_page = endpg;
			eng_doc_addr();			/* select DOC RAM autoinc at up_write */
		}
		while (rem24 > 0) {
			chunk = (rem24 > UPBUF_SZ) ? UPBUF_SZ : (int)rem24;
			chunk = fread(upbuf, 1, chunk, fp);
			if (chunk == 0)
				break;			/* EOF/short -> stop this instrument */
			if (up_write)
				eng_doc_write_chunk();
			else if (pool_ok)
				eng_pool_write_chunk();
			rem24 = rem24 - chunk;
		}
	}
	printf("uploaded\n");

loaded:
	printf("ntpplay: play\n");

	/* ---- song init ---- */
	rowstep = ntracks * 4;			/* bytes per row across all tracks */
	trigcnt = 0;
	pend_jump = 0;
	start_row = 0;
	master_vol = 0x0F;			/* full */
	for (t = 0; t < MAX_TRACKS; t++)
		last_ins[t] = 0;		/* persisted instrument (whole song) */
	for (t = 0; t < MAX_TRACKS; t++) {
		strm_base_pg[t] = (STREAM_BUF_TOP - t * 2) & 0xFF;	/* 2-page stream buffer */
		strm_pg_off[t] = 0;
	}
	for (i = 0; i < NUM_OSC; i++)
		osc_strm_trk[i] = 0;		/* stream osc -> track map */

	if (g_inspect) {
		eng_inspect_run();		/* -i audition (no-op for now) */
		goto songend;
	}

	songpos = 0;
	if (!eng_load_pattern())		/* initial pattern */
		goto songend;
	ttick = 0;
	g_done = 0;
	g_abort = 0;

	if (!g_check && res_ok) {
		/* engine-in-IRQ: the osc-31 timer handler drives do_one_tick ~50 Hz;
		 * the foreground just polls keys and sleeps between ticks. */
		eng_irq_install();
		while (!g_abort && !g_done) {
			eng_poll_keyboard();
			if (g_autoquit) {
				if (eng_wait_irq() >= 200)	/* -Q: self-abort ~4 s in */
					g_abort = 1;
			} else {
				eng_wait_irq();
			}
		}
		eng_irq_uninstall();		/* halts oscs + restores the vector */
	} else {
		/* foreground tick loop (-c headless / non-resident): do_one_tick here. */
		while (!g_abort) {
			eng_poll_keyboard();
			if (g_abort)
				break;
			eng_do_one_tick();
			if (g_done)
				break;
			eng_wait_tick();	/* pace (no-op under -c) */
		}
		if (!g_check)
			eng_doc_halt();		/* teardown (no IRQ path did it) */
	}

songend:
	print_diag();
	printf("ntpplay: trig %02X\n", trigcnt & 0xFF);
	printf("ntpplay: done\n");
	fclose(fp);
	if (res_ok)
		eng_res_free();			/* MM blocks are userID-owned, not auto-freed */
	if (pool_ok)
		eng_pool_free();
	return 0;

shorterr:
	printf("short read\n");
	fclose(fp);
	return 1;
}
