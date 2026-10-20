/* fractal - fixed-point Mandelbrot/Julia explorer for the FGX SHR console.
 *
 * FGX-Provenance: none.  Original FGX code, not a BSD port.  It CITES 2.11BSD
 * below because the device it asks about (/dev/tty) is ported from there, but
 * no line here derives from it.
 *
 * Q9 fixed point. The escape-count iteration is done by the asm quarter-square
 * engine (fractal_stubs.s): ab = T[|a+b|]-T[|a-b|], z^2 = T[|2z|], table
 * floor(n^2/4) built add-only. ~7x faster than fcc software long-mul on the
 * multiply-less 65816. Q9 = ~6x subpixel at base view; deep zoom is the future
 * (bigger table / NCR accelerator). C mandel_iter kept for the --sum oracle.
 *
 * Compute STREAMS one scanline at a time (range-fit palettes are per-line),
 * so there is no 64000-byte iteration buffer to strain the data segment.
 *
 * Default mode is the interactive 16-color explorer (arrows/hjkl crosshair,
 * Enter zoom, ESC/q exit). `--sum`/`--sumasm` print the oracle checksum
 * verified bit-for-bit against tools/fractal-ref. The --3200 per-scanline
 * palette paths are parked experiments (see docs/history plans/RESUMEs).
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define FBITS 9
#define ESC   (4L << FBITS)          /* |z|^2 > 4.0 in Q9 */

/* (a*b)>>9, signed 32-bit. Must stay bit-identical to fractal_ref fix_mul. */
long fix_mul(a, b)
long a, b;
{
	return (a * b) >> FBITS;
}

/* Mandelbrot escape iteration for c=(cr,ci), z0=0. Capped at 255. */
int mandel_iter(cr, ci, maxit)
long cr, ci;
int maxit;
{
	long zr, zi, zr2, zi2, nzr;
	int n;

	zr = 0;
	zi = 0;
	for (n = 0; n < maxit; n++) {
		zr2 = fix_mul(zr, zr);
		zi2 = fix_mul(zi, zi);
		if (zr2 + zi2 > ESC)
			break;
		nzr = zr2 - zi2 + cr;
		zi = (fix_mul(zr, zi) << 1) + ci;
		zr = nzr;
	}
	if (n > 255)
		n = 255;
	return n;
}

/* Julia escape iteration: c=(jcr,jci) fixed, z0=(cr,ci) the pixel. Capped 255. */
int julia_iter(cr, ci, jcr, jci, maxit)
long cr, ci, jcr, jci;
int maxit;
{
	long zr, zi, zr2, zi2, nzr;
	int n;

	zr = cr;
	zi = ci;
	for (n = 0; n < maxit; n++) {
		zr2 = fix_mul(zr, zr);
		zi2 = fix_mul(zi, zi);
		if (zr2 + zi2 > ESC)
			break;
		nzr = zr2 - zi2 + jcr;
		zi = (fix_mul(zr, zi) << 1) + jci;
		zr = nzr;
	}
	if (n > 255)
		n = 255;
	return n;
}

/* Compute a w*h tile, djb2 checksum over iteration bytes, print ITSUM.
 * Bit-identical to fractal_ref --sum (the on-device oracle tie). */
int do_sum(cr0, ci0, step, w, h, maxit)
long cr0, ci0, step;
int w, h, maxit;
{
	long sum, cr, ci;
	int px, py, v;

	sum = 5381;
	ci = ci0;
	for (py = 0; py < h; py++) {
		cr = cr0;
		for (px = 0; px < w; px++) {
			v = mandel_iter(cr, ci, maxit);
			sum = ((sum << 5) + sum) + v;   /* sum*33 + v */
			cr = cr + step;
		}
		ci = ci + step;
	}
	printf("ITSUM=%ld\n", sum);
	return 0;
}

/* ---- Direct SHR draw (tier-1: 16-color single palette) ----
 * Claims the screen (SYS_SCREEN_CTL suspends the console flush), then writes
 * the bank-$01 SHR shadow via the fractal_stubs.s asm companion (fcc can't
 * form far pointers to absolute addresses; ntpplay uses the same pattern for
 * DOC sound). Data crosses to asm through these seg1 globals. The kernel
 * auto-restores the console when this task dies.
 */
unsigned char g_row[160];		/* current scanline, 4bpp packed */
unsigned char g_pal[32];		/* palette 0 (16 colors x 2 bytes) */
int g_off;				/* dest byte offset into SHR (y*160) */

/* Quarter-square multiply engine state (shared with fractal_stubs.s).
 * Sizes follow from the iteration's component pre-check (|zr|,|zi| <= 2048
 * always holds when a table is consulted): _sqz indexes g_qsq9 by |2z| <=
 * 4096; g_qsq's largest consumer is _qmul9's |u+v| <= 7168 (cubic). The
 * tables once spanned n<=9728 for the unchecked mandel transient -- the
 * pre-check retired that, freeing ~21KB of the data bank. */
long g_qsq[7169];			/* table: floor(n^2/4), n=0..7168 (28676 B) */
int g_qsq9[4097];			/* pre-shifted squares: T[n]>>9 (z^2 in one load) */
int g_i9;				/* build: byte index into g_qsq9 */
long g_sq;				/* build: running square */
long g_cr, g_ci;			/* mand_asm inputs (Q9, low 16 = signed value) */
int g_odd, g_maxit;
int g_zr, g_zi, g_zr2, g_zi2, g_newzi;	/* iteration accumulators (16-bit) */
int g_tlo, g_thi, g_crlo, g_crhi;	/* asm scratch */
int g_iy, g_ia, g_iq, g_alo, g_ahi;	/* interior-check scratch (_intchk) */
int g_pzr, g_pzi, g_bpow, g_bdst;	/* Brent periodicity: checkpoint z, power, dist */
int g_fmode;				/* 0 mandel, 1 julia, 2 tricorn, 3 ship, 4 cubic */
int g_jcr, g_jci;			/* julia constant c (Q9) */
int g_wcr, g_wci;			/* iteration's working c (asm-internal) */
int g_mu, g_mv;				/* _qmul9 operands */
int g_esum;				/* |z|^2 at escape (2049..~16K, log-ish) */
unsigned char g_iter[320];		/* one line's iteration counts (for range-fit) */
int g_paln;				/* hw palette index for shr_setpaln (0..15) */
unsigned char g_scb[200];		/* per-scanline SCB bytes (320 mode, palette=band) */
int g_cx, g_cy;				/* crosshair position (pixels) */
int g_cvis;				/* 1 = crosshair currently drawn on screen */
int g_msk;				/* shr_xorpix nibble mask ($F0 even x, $0F odd) */
int g_rainbow;				/* 1 = --rainbow palette (default grey ramp) */

int yield();
int waitkey();				/* libfgx: block until a keypress */
void shr_go320();			/* fractal_stubs.s */
void shr_setpal();
void shr_setpaln();			/* g_pal -> hw palette g_paln (0..15) */
void shr_setscbs();			/* g_scb[0..199] -> SHR SCBs (per-scanline palette) */
void shr_putrow();
void shr_done();
void scr_suspend();			/* claim screen (suspend console flush) */
void scr_restore();
void mand_build();			/* build g_qsq (add-only) */
int mand_asm();				/* escape count for (g_cr,g_ci), maxit g_maxit */
int g_palv;				/* palette-table index for gfx_pset (fill) */
int g_palline;				/* palette-table index for pal_load (beam-poll) */
void gfx_pset();			/* store g_pal[32] -> GFX_PALTAB[g_palv] */
void scr_arm();				/* start the 3200 scanline engine (claim+arm) */
void scr_disarm();
int rd_vcnt();				/* VGC vertical counter ($C02E low byte) */
int rd_vbl();				/* RDVBL ($C019): bit7 = vertical blanking */
void irq_off();				/* SEI: mask IRQs for flicker-free palette timing */
void irq_on();				/* CLI */
int kbd_poll();				/* hardware keyboard poll (works under SEI): 1/-1 */
void pal_load();			/* GFX_PALTAB[g_palline] -> hw palette 0 */
int pollkey();				/* libfgx: key code, or -1 if none */
void shr_xorpix();			/* XOR g_msk into SHR byte g_off (crosshair) */
void shr_getrow();			/* SHR_PIXELS + g_off -> g_row (progressive) */

/* Store one 16-entry palette (all entries = the given 12-bit RGB) at table
 * index v. Used by both the static test and the fractal 3200 render. */
void put_line_palette(v, rgb)
int v, rgb;
{
	int i;
	for (i = 0; i < 16; i++) {
		g_pal[i * 2]     = (((rgb >> 4) & 15) << 4) | (rgb & 15);
		g_pal[i * 2 + 1] = (rgb >> 8) & 15;
	}
	g_palv = v;
	gfx_pset();
}

/* Static engine test: fill 256 per-line palettes with a vertical rainbow and a
 * solid index-1 screen. If the scanline engine works, the screen shows a smooth
 * vertical color sweep (each line its own palette); if not, one flat color. */
/* Full 6-segment HSV rainbow -> 12-bit RGB. h in 0..255 sweeps red->yellow->
 * green->cyan->blue->magenta->red. */
int rainbow(h)
int h;
{
	int seg, f, r, g, b;
	seg = (h * 6) >> 8;		/* 0..5 */
	f = ((h * 6) & 255) >> 4;	/* 0..15 within the segment */
	if (seg == 0)      { r = 15;     g = f;      b = 0;      }
	else if (seg == 1) { r = 15 - f; g = 15;     b = 0;      }
	else if (seg == 2) { r = 0;      g = 15;     b = f;      }
	else if (seg == 3) { r = 0;      g = 15 - f; b = 15;     }
	else if (seg == 4) { r = f;      g = 0;      b = 15;     }
	else               { r = 15;     g = 0;      b = 15 - f; }
	return (r << 8) | (g << 4) | b;
}

int do_gfx3200test()
{
	int v, x, line, last;

	scr_suspend();			/* claim screen (console off) before drawing */
	shr_go320();
	for (v = 0; v < 256; v++)	/* vivid rainbow, cycled 3x so the visible band shows a full sweep */
		put_line_palette(v, rainbow((v * 3) & 255));
	for (x = 0; x < 160; x++)	/* solid index-1 everywhere */
		g_row[x] = 0x11;
	for (v = 0; v < 200; v++) {
		g_off = v * 160;
		shr_putrow();
	}
	shr_done();			/* headless capture marker */

	/* Beam-poll: reload hw palette 0 per scanline from GFX_PALTAB, synced to
	 * the VGC vertical counter. No kernel IRQ (no ack/storm risk); preemptible,
	 * so Ctrl-C and the key-exit below both work. */
	last = 999;
	for (;;) {
		line = rd_vcnt();
		if (line != last) {
			if (line < last) {		/* frame wrapped: check exit once/frame */
				if (pollkey() != -1)
					break;
			}
			g_palline = line;
			pal_load();
			last = line;
		}
	}
	scr_restore();			/* release screen, repaint console */
	return 0;
}

/* Built-in palettes (16 RGB12 entries each; index 0 = interior black).
 * 'p' live-cycles them -- pixels are palette indices, so rewriting hardware
 * palette 0 recolors the finished image instantly, no recompute. A user
 * palette from /etc/fractal.pal (16 hex RGB12 values, whitespace-separated)
 * joins the cycle when present. */
int pal_greyred[16] = {			/* default: red-weighted grey-to-red */
	0x000, 0x111, 0x222, 0x333, 0x444, 0x555, 0x633, 0x711,
	0x800, 0x900, 0xA00, 0xB00, 0xC00, 0xD00, 0xE00, 0xF00
};
int pal_grey[16] = {
	0x000, 0x111, 0x222, 0x333, 0x444, 0x555, 0x666, 0x777,
	0x888, 0x999, 0xAAA, 0xBBB, 0xCCC, 0xDDD, 0xEEE, 0xFFF
};
int pal16[16] = {			/* vivid rainbow */
	0x000, 0x008, 0x00F, 0x05F, 0x0AF, 0x0FF, 0x0F8, 0x0F0,
	0x8F0, 0xFF0, 0xFA0, 0xF80, 0xF40, 0xF00, 0xF0F, 0xFFF
};
int pal_fire[16] = {
	0x000, 0x200, 0x400, 0x600, 0x800, 0xA00, 0xC00, 0xE20,
	0xF40, 0xF60, 0xF80, 0xFA0, 0xFC0, 0xFE0, 0xFF8, 0xFFF
};
int pal_ice[16] = {
	0x000, 0x002, 0x004, 0x006, 0x008, 0x00A, 0x00C, 0x02E,
	0x04F, 0x26F, 0x48F, 0x6AF, 0x8CF, 0xAEF, 0xCFF, 0xFFF
};
int g_upal[16];				/* user palette (/etc/fractal.pal) */
int g_haveupal;				/* 1 = g_upal loaded and valid */
int g_palidx;				/* current palette in the cycle */

/* Install palette g_palidx (0 greyred, 1 grey, 2 rainbow, 3 fire, 4 ice,
 * 5 user when loaded) into hardware palette 0. */
int *curpal()
{
	if (g_palidx == 1)      return pal_grey;
	if (g_palidx == 2)      return pal16;
	if (g_palidx == 3)      return pal_fire;
	if (g_palidx == 4)      return pal_ice;
	if (g_palidx == 5)      return g_upal;
	return pal_greyred;
}

/* 4-anchor RGB12 ramps: 60 interpolated positions with /20 channel precision
 * hit REAL distinct colors (entry-lerp collapsed onto the 15 base entries).
 * Rainbow/user palettes have no meaningful anchor path: entry-lerp fallback. */
int anch_greyred[4] = { 0x111, 0x666, 0xA33, 0xF00 };
int anch_grey[4]    = { 0x111, 0x555, 0xAAA, 0xFFF };
int anch_fire[4]    = { 0x100, 0x800, 0xF80, 0xFFF };
int anch_ice[4]     = { 0x012, 0x24C, 0x6BF, 0xFFF };

/* RGB12 at fine ramp position t (0..59). */
int rampcol(t)
int t;
{
	int f, a, b, r, g, bl;
	int *ap;
	int *pp;

	ap = 0;
	if (g_palidx == 0)      ap = anch_greyred;
	else if (g_palidx == 1) ap = anch_grey;
	else if (g_palidx == 3) ap = anch_fire;
	else if (g_palidx == 4) ap = anch_ice;
	if (ap) {
		f = t / 20;		/* segment 0..2 */
		a = ap[f];
		b = ap[f + 1];
		f = t - f * 20;		/* 0..19 within the segment */
		r  = (((a >> 8) & 15) * (20 - f) + ((b >> 8) & 15) * f) / 20;
		g  = (((a >> 4) & 15) * (20 - f) + ((b >> 4) & 15) * f) / 20;
		bl = ((a & 15) * (20 - f) + (b & 15) * f) / 20;
		return (r << 8) | (g << 4) | bl;
	}
	pp = curpal();
	f = t & 3;
	a = pp[1 + (t >> 2)];
	b = (t >> 2 < 14) ? pp[2 + (t >> 2)] : pp[15];
	r  = (((a >> 8) & 15) * (4 - f) + ((b >> 8) & 15) * f) >> 2;
	g  = (((a >> 4) & 15) * (4 - f) + ((b >> 4) & 15) * f) >> 2;
	bl = ((a & 15) * (4 - f) + (b & 15) * f) >> 2;
	return (r << 8) | (g << 4) | bl;
}

void set_palette()
{
	int i, rgb;
	int *pp;

	pp = curpal();
	for (i = 0; i < 16; i++) {
		rgb = pp[i];
		/* hardware entry: byte0 = GGGGBBBB, byte1 = 0000RRRR */
		g_pal[i * 2]     = (((rgb >> 4) & 15) << 4) | (rgb & 15);
		g_pal[i * 2 + 1] = (rgb >> 8) & 15;
	}
	shr_setpal();
}

/* ---- In-app help (h or ?): a text box drawn over the graphics screen ----
 * Uses the console's own 6x8 font, read from /lib/fonts/default.fnt (FGXF v1:
 * 48-byte header + 95 glyphs x 8 bytes, ASCII 32..126, MSB = leftmost pixel).
 * The box overwrites image pixels; dismissing re-renders (progressive, so the
 * picture is back in under a second). */
unsigned char g_font[760];		/* glyph block */
int g_havefont;

void load_font()
{
	int fd, n;

	fd = open("/lib/fonts/default.fnt", 0);
	if (fd < 0)
		return;
	n = read(fd, g_row, 48);	/* header (reuse g_row as scratch) */
	if (n == 48 && g_row[0] == 'F' && g_row[1] == 'G' &&
	    g_row[2] == 'X' && g_row[3] == 'F') {
		n = read(fd, g_font, 760);
		if (n == 760)
			g_havefont = 1;
	}
	close(fd);
}

char *helptxt[] = {
	"FRACTAL EXPLORER",
	"",
	"arrows       move crosshair 1 pixel",
	"ctrl-arrows  move 8 pixels (or HJKL)",
	"enter        zoom 2x at crosshair",
	"f            cycle fractal type",
	"j            julia of crosshair point",
	"p            cycle palette",
	"3            3200-color showcase",
	"esc          back (julia) / exit",
	"q            quit",
	"h or ?       this help",
	"",
	"keys work while rendering.",
	"see fractal(1) for palettes.",
	"press any key"
};
#define NHELP 16

/* Box: border 2px (index 15), black fill, text rows at y=34+8*row.
 * Speed: everything is DIRECT byte stores into g_row -- the box interior is
 * whole bytes (x 36..283 = bytes 18..141), and the text starts at an even
 * column (x=44, byte 22) with 6px glyphs, so every char is exactly 3 aligned
 * bytes per scanline. (A per-pixel setnib() helper here once cost ~36000
 * function calls and rendered the box in seconds.) */
void do_help()
{
	int sy, row, gr, i, ch, b, o;
	char *s;

	if (!g_havefont)
		return;			/* no font on disk: skip silently */
	for (sy = 26; sy <= 169; sy++) {
		g_off = sy * 160;
		shr_getrow();		/* preserve pixels beside the box */
		if (sy <= 27 || sy >= 168) {
			for (i = 18; i <= 141; i++)
				g_row[i] = 0xFF;	/* top/bottom border */
		} else {
			g_row[18] = 0xFF;	/* side borders + black fill */
			for (i = 19; i <= 140; i++)
				g_row[i] = 0;
			g_row[141] = 0xFF;
			row = (sy - 34) >> 3;
			gr = (sy - 34) & 7;
			if (sy >= 34 && row < NHELP) {
				s = helptxt[row];
				o = 22;
				for (i = 0; s[i] != 0; i++) {
					ch = s[i];
					if (ch < 32 || ch > 126)
						ch = 32;
					b = g_font[(ch - 32) * 8 + gr];
					g_row[o] = ((b & 0x80) ? 0xF0 : 0)
					    | ((b & 0x40) ? 0x0F : 0);
					g_row[o + 1] = ((b & 0x20) ? 0xF0 : 0)
					    | ((b & 0x10) ? 0x0F : 0);
					g_row[o + 2] = ((b & 0x08) ? 0xF0 : 0)
					    | ((b & 0x04) ? 0x0F : 0);
					o = o + 3;
				}
			}
		}
		shr_putrow();
	}
	getkey();			/* any key dismisses; caller re-renders */
}

/* Load /etc/fractal.pal: 16 whitespace-separated hex RGB12 values
 * (e.g. "000 111 ... F00"). Sets g_haveupal on success; silent otherwise. */
void load_upal()
{
	int fd, n, i, v, digs, k;
	char buf[128];
	char c;

	fd = open("/etc/fractal.pal", 0);
	if (fd < 0)
		return;
	n = read(fd, buf, 127);
	close(fd);
	if (n <= 0)
		return;
	i = 0;
	v = 0;
	digs = 0;
	for (k = 0; k <= n; k++) {
		c = (k < n) ? buf[k] : ' ';	/* virtual trailing separator */
		if (c >= '0' && c <= '9') {
			v = (v << 4) | (c - '0');
			digs++;
		} else if (c >= 'a' && c <= 'f') {
			v = (v << 4) | (c - 'a' + 10);
			digs++;
		} else if (c >= 'A' && c <= 'F') {
			v = (v << 4) | (c - 'A' + 10);
			digs++;
		} else if (digs > 0) {
			if (digs > 3 || i >= 16)
				return;		/* malformed: keep builtins only */
			g_upal[i] = v;
			i++;
			v = 0;
			digs = 0;
		}
	}
	if (i == 16)
		g_haveupal = 1;
}

/* Full 320x200 render using the asm quarter-square mand_asm (fast enough now
 * that the 65816-multiply-less compute isn't fcc's software long-mul). */
#define MAXIT 40

/* ---- Interactive explorer (tier-1 render + crosshair zoom) ----
 * Single pass, one palette. View state in Q9: window top-left (v_cr0,v_ci0),
 * per-pixel step v_step. Enter zooms 2x centered on the crosshair; integer Q9
 * steps allow 6 -> 3 -> 1, then Enter is inert (max zoom ~6x; deeper needs a
 * wider multiply -- see docs/history/plans/2026-07-21-fractal-v1-explorer.md).
 * Keys: arrows/hjkl move 1px, Ctrl-arrows/HJKL move 8px, Enter zoom,
 * ESC/q exit (also mid-render). */
#define K_LEFT  0x08
#define K_DOWN  0x0A
#define K_UP    0x0B
#define K_RIGHT 0x15
#define K_ENTER 0x0D
#define K_ESC   0x1B
/* Naked-arrow vt100 sequences fold to these DISTINCT codes -- they must not
 * collide with letters ('j' is the julia key; that collision once made the
 * down arrow launch a julia render). */
#define K_SUP   0x141
#define K_SDN   0x142
#define K_SRT   0x143
#define K_SLT   0x144

long v_cr0, v_ci0, v_step;
int v_maxit;
int bay4[4] = { 0, 2, 3, 1 };		/* 2x2 Bayer ordered-dither thresholds */
int g_dither = 1;			/* --nodither clears (default on) */
unsigned char g_fmap[256];		/* fine count -> ramp position 0..59,
					 * quarter-log2 stretched over the counts
					 * actually present (linear wasted the
					 * ramp: exterior = counts 1-6) */

int qlog(v)
int v;
{
	int l;
	if (v < 4)
		v = 4;
	if (v > 255)
		v = 255;
	l = 0;
	while (v >= 8) {
		v = v >> 1;
		l = l + 4;
	}
	return l + v - 4;	/* 4*log2 quarter steps */
}

void build_fmap()
{
	int f, lmax;
	lmax = qlog(4 * v_maxit - 1);
	if (lmax < 1)
		lmax = 1;
	for (f = 0; f < 256; f++)
		g_fmap[f] = (qlog(f) * 59) / lmax;
}

/* ---- Static per-scanline palettes (SCBs only, zero ongoing CPU) ----
 * Coarse progressive passes record each line's escaping-count span; before
 * the final pass the 200 lines are grouped into 16 span-similar clusters and
 * each group's palette becomes a DENSER SLICE of the same global ramp
 * (interpolated), so a given count's color varies only subtly line-to-line
 * (the stripe cure). The final pass quantizes each line against its group
 * window. See docs/history/plans/2026-07-21-fractal-static-scanline-palettes.md */
unsigned char g_slo[200], g_shi[200];	/* per-line span (255/0 = none) */
int g_gl[16], g_gh[16];			/* group count windows */
int g_sp;				/* 1 = per-scanline palettes active */

/* Home view for the current fractal mode. */
void sethome()
{
	if (g_fmode == 4) {		/* cubic multibrot: radius ~1.25 */
		v_cr0 = -640L;
		v_ci0 = -400L;
		v_step = 4L;
	} else if (g_fmode == 1) {	/* julia: centered z-plane */
		v_cr0 = -960L;
		v_ci0 = -600L;
		v_step = 6L;
	} else {			/* mandel / tricorn / ship */
		v_cr0 = -1216L;
		v_ci0 = -600L;
		v_step = 6L;
	}
	v_maxit = MAXIT;
}

/* XOR-invert one 4bpp pixel in the SHR shadow (crosshair draw/erase). */
void xorpix(x, y)
int x, y;
{
	g_off = y * 160 + (x >> 1);
	g_msk = (x & 1) ? 0x0F : 0xF0;
	shr_xorpix();
}

/* 9px cross at (g_cx,g_cy); XOR, so a second call erases it. The position is
 * clamped to 4..315 x 4..195 so no per-pixel edge checks are needed. */
void xorcross()
{
	int i;
	for (i = -4; i <= 4; i++) {
		xorpix(g_cx + i, g_cy);
		if (i)
			xorpix(g_cx, g_cy + i);
	}
}

/* Fold a raw key, translating vt100 arrow sequences to K_S* codes. The
 * kernel heartbeat translates naked arrows into ESC [ A/B/C/D (enqueued
 * ATOMICALLY, so after an arrow's ESC the '[' is already in the ring and one
 * pollkey() disambiguates a bare ESC race-free). Ctrl+arrows arrive raw
 * ($08/$0A/$0B/$15 = K_*, the COARSE codes). Unknown ESC tails return -2
 * (caller ignores). */
int foldkey(k)
int k;
{
	if (k != K_ESC)
		return k;
	k = pollkey();
	if (k == -1)
		return K_ESC;		/* bare ESC */
	if (k == '[') {
		k = waitkey();		/* A/B/C/D (already queued) */
		if (k == 'A') return K_SUP;
		if (k == 'B') return K_SDN;
		if (k == 'C') return K_SRT;
		if (k == 'D') return K_SLT;
	}
	return -2;			/* unknown sequence: ignore */
}

int getkey()				/* blocking folded key */
{
	return foldkey(waitkey());
}

int pollgetkey()			/* nonblocking folded key; -1 = none */
{
	int k;

	k = pollkey();
	return (k == -1) ? -1 : foldkey(k);
}

/* Move (and if hidden, summon) the crosshair: erase, shift, clamp, redraw.
 * Works both from the crosshair phase and mid-render. */
void movecross(dx, dy)
int dx, dy;
{
	if (g_cvis)
		xorcross();		/* erase before moving */
	g_cvis = 1;
	g_cx = g_cx + dx;
	g_cy = g_cy + dy;
	if (g_cx < 4)   g_cx = 4;
	if (g_cx > 315) g_cx = 315;
	if (g_cy < 4)   g_cy = 4;
	if (g_cy > 195) g_cy = 195;
	xorcross();
}

/* Group the 200 lines into 16 span-similar clusters, build each group's
 * palette as a denser interpolated slice of the current base ramp, install
 * palettes + SCBs. Called just before the final progressive pass. */
/* THE STRIPE THEOREM (learned twice now): color must be a GLOBAL function of
 * the escape count. Any per-line rescaling of count->color makes the same
 * count differ across lines = horizontal streaks. So: a narrow-span line
 * (<= 14 distinct counts) gets a palette whose slot 1+(c-wlo) holds EXACTLY
 * the global ramp color of count c -- full per-count color resolution,
 * streak-free by construction. Wide lines keep the global quantized path
 * (palette 0, rebuilt from the same ramp). Lines bucket by their span LO
 * into palettes 1..15; a line whose hi overflows its bucket window falls
 * back to global. */
void build_spal()
{
	int y, g, m0, m1, i, t, rgb, lo;

	m0 = 999;			/* range of narrow-line lo values */
	m1 = 0;
	for (y = 0; y < 200; y++) {
		if (g_slo[y] <= g_shi[y] && g_shi[y] - g_slo[y] <= 14) {
			if (g_slo[y] < m0) m0 = g_slo[y];
			if (g_slo[y] > m1) m1 = g_slo[y];
		}
	}
	if (m0 > m1)
		return;			/* no narrow lines: stay global */
	for (g = 1; g <= 15; g++)
		g_gl[g] = -1;
	for (y = 0; y < 200; y++) {
		g_scb[y] = 0;		/* default: global palette 0 */
		lo = g_slo[y];
		if (lo > g_shi[y] || g_shi[y] - lo > 14)
			continue;
		g = 1 + ((lo - m0) * 15) / (m1 - m0 + 1);
		if (g > 15)
			g = 15;
		if (g_gl[g] < 0 || lo < g_gl[g])
			g_gl[g] = lo;	/* window base = bucket's lowest lo */
		g_scb[y] = g;
	}
	for (y = 0; y < 200; y++) {	/* hi beyond the window: fall back */
		g = g_scb[y];
		if (g && g_shi[y] > g_gl[g] + 14)
			g_scb[y] = 0;
	}
	for (g = 0; g <= 15; g++) {
		if (g && g_gl[g] < 0)
			g_gl[g] = 0;
		g_pal[0] = 0;		/* interior stays black everywhere */
		g_pal[1] = 0;
		for (i = 1; i < 16; i++) {
			/* palette 0: global quantization cell centers;
			 * palettes 1..15: the exact color of count wlo+i-1 */
			if (g == 0)
				t = (i - 1) * 4 + 2;
			else
				t = g_fmap[(g_gl[g] + i - 1) > 255
				    ? 255 : (g_gl[g] + i - 1)];
			if (t > 59)
				t = 59;
			rgb = rampcol(t);
			g_pal[i * 2]     = (((rgb >> 4) & 15) << 4) | (rgb & 15);
			g_pal[i * 2 + 1] = (rgb >> 8) & 15;
		}
		g_paln = g;
		shr_setpaln();
	}
	shr_setscbs();
	g_sp = 1;
}

/* 3200-color showcase ('3'): recompute the view with PER-LINE quantization
 * (each line range-fit to its own fine-count window; the palette holds that
 * window's true global-curve colors -- the proven stripe-free variant), stage
 * 200 palettes in GFX_PALTAB at the calibrated $C02E slots, arm the kernel
 * VGC scanline-IRQ engine (~80% CPU at 7 MHz -- a static showcase, not a
 * mode). Any key disarms; the kernel restores the console, so we re-claim
 * and the caller re-renders the interactive view. */
void do_show3200()
{
	long cr, ci;
	int x, y, c, i, lo, hi, idx, f, rgb, fine, span;

	for (y = 0; y < 200; y++) {
		ci = v_ci0 + v_step * y;
		cr = v_cr0;
		lo = 999;
		hi = 0;
		for (x = 0; x < 320; x++) {
			g_cr = cr;
			g_ci = ci;
			c = mand_asm();
			if (c >= v_maxit)
				fine = 255;	/* interior marker */
			else {
				i = g_esum >> 12;
				if (i > 3)
					i = 3;
				fine = (c << 2) | (3 - i);
				if (fine > 254)
					fine = 254;
				if (fine < lo) lo = fine;
				if (fine > hi) hi = fine;
			}
			g_iter[x] = fine;
			cr = cr + v_step;
		}
		if (lo > hi) {
			lo = 4;
			hi = 5;
		}
		span = hi - lo;
		g_pal[0] = 0;		/* interior black */
		g_pal[1] = 0;
		for (i = 1; i < 16; i++) {
			/* narrow line: exact per-fine-count colors; wide line:
			 * the GLOBAL quantization cells -- identical on every
			 * wide line, so no stripes (the original stripe-free
			 * rule: never range-fit a wide line to itself) */
			if (span <= 14) {
				f = lo + i - 1;
				rgb = rampcol(g_fmap[f > 255 ? 255 : f]);
			} else
				rgb = rampcol((i - 1) * 4 + 2);
			g_pal[i * 2]     = (((rgb >> 4) & 15) << 4) | (rgb & 15);
			g_pal[i * 2 + 1] = (rgb >> 8) & 15;
		}
		g_palv = 127 + (y * 96) / 199;	/* measured $C02E slot */
		gfx_pset();
		for (x = 0; x < 320; x++) {
			fine = g_iter[x];
			if (fine == 255)
				idx = 0;
			else if (span <= 14)
				idx = 1 + (fine - lo);
			else
				idx = 1 + (g_fmap[fine] >> 2);
			if (idx > 15)
				idx = 15;
			if (x & 1)
				g_row[x >> 1] |= idx;
			else
				g_row[x >> 1] = idx << 4;
		}
		g_off = y * 160;
		shr_putrow();
		i = pollkey();
		if (i == 'q' || i == K_ESC)
			break;		/* abort: skip the arm */
	}
	if (y >= 200) {
		scr_arm();		/* per-scanline palettes go LIVE */
		getkey();		/* admire; any key ends the showcase */
		scr_disarm();		/* kernel restores the console (640) */
	}
	scr_suspend();			/* re-claim for the interactive view */
	shr_go320();
	set_palette();
}

/* Advance the live palette cycle (works mid-render too: instant recolor). */
void cyclepal()
{
	g_palidx = g_palidx + 1;
	if (g_palidx > (g_haveupal ? 5 : 4))
		g_palidx = 0;
	set_palette();
	if (g_sp)
		build_spal();		/* re-slice the 16 group palettes */
}

/* Progressive render: passes p = 8,4,2,1 compute every p-th lattice pixel and
 * fill p-wide blocks, so a chunky full-screen preview lands in ~1/64 of the
 * render time and sharpens in place. Later passes SKIP lattice points a
 * coarser pass computed -- their block on screen already shows that exact
 * value, so skip-rows re-read the SHR row (shr_getrow) before the write-back
 * and only the new blocks are touched. Every pixel is computed exactly once
 * by mand_asm: the finished image is identical to a single-pass render.
 * Mirror (axis-symmetric views): rows 0..100 computed, each written row 1..99
 * also stored at 200-row; coarse blocks straddle the axis until finer passes
 * correct them, and the final pass is exact.
 * Coloring: grey-to-red MONOTONIC ramp 1..15 over [0,maxit) (not
 * mod-cycling); --rainbow keeps the classic 1+(c%15) bands.
 * ESC/q polled between bands aborts; returns the aborting key (0 = done). */
int render()
{
	long cr, ci, stepp;
	int x, y, c, idx, k, p, r, i, row, ylim, mirror, skiprow, m, b, hit;
	int slo2, sw, fine;

	/* X-axis conjugate symmetry holds for mandel/tricorn/cubic; julia is
	 * point-symmetric (not row-mirrorable) and the ship has none. */
	mirror = (v_ci0 == -100L * v_step)
	    && g_fmode != 1 && g_fmode != 3;
	if (g_sp) {			/* previous frame's line palettes off */
		for (i = 0; i < 200; i++)
			g_scb[i] = 0;
		shr_setscbs();
		set_palette();
		g_sp = 0;
	}
	for (i = 0; i < 200; i++) {	/* reset per-line span collection */
		g_slo[i] = 255;
		g_shi[i] = 0;
	}
	slo2 = 0;
	sw = 1;
	build_fmap();
	ylim = mirror ? 100 : 199;
	for (p = 8; p >= 1; p = p >> 1) {
		if (p == 1 && !g_rainbow)
			build_spal();	/* exact fine-count line palettes */
		stepp = v_step * p;
		m = p + p - 1;		/* lattice mask: & m == % (2p), p is a power of 2 */
		for (y = 0; y <= ylim; y += p) {
			sw = 0;		/* final pass: this line's exact window */
			if (g_sp) {
				sw = g_scb[y];
				if (sw)
					slo2 = g_gl[sw];
			}
			skiprow = (p < 8) && (y & m) == 0;
			/* A live crosshair must not be baked into the image: if
			 * this band's rows (or their mirrors) overlap it, erase
			 * it before the read-back/writes and redraw after. */
			hit = 0;
			if (g_cvis) {
				if (y <= g_cy + 4 && y + p - 1 >= g_cy - 4)
					hit = 1;
				if (mirror && 200 - (y + p - 1) <= g_cy + 4
				    && 200 - y >= g_cy - 4)
					hit = 1;
				if (hit)
					xorcross();
			}
			if (skiprow) {	/* preserve blocks that are already final */
				g_off = y * 160;
				shr_getrow();
			}
			ci = v_ci0 + v_step * y;
			cr = v_cr0;
			for (x = 0; x < 320; x += p) {
				if (skiprow && (x & m) == 0) {
					cr = cr + stepp;
					continue;	/* computed by a coarser pass */
				}
				g_cr = cr;
				g_ci = ci;
				c = mand_asm();
				fine = 0;
				if (c < v_maxit) {
					/* FINE count = count*4 + 2 fractional
					 * bits from |z|^2 at escape (barely
					 * escaped = higher fraction). All
					 * coloring is a GLOBAL function of it. */
					i = g_esum >> 12;
					if (i > 3)
						i = 3;
					fine = (c << 2) | (3 - i);
					if (fine > 255)
						fine = 255;
					if (fine < g_slo[y]) g_slo[y] = fine;
					if (fine > g_shi[y]) g_shi[y] = fine;
					if (mirror && y >= 1 && y <= 99) {
						if (fine < g_slo[200 - y]) g_slo[200 - y] = fine;
						if (fine > g_shi[200 - y]) g_shi[200 - y] = fine;
					}
				}
				if (c >= v_maxit)
					idx = 0;	/* interior: crisp black */
				else if (g_rainbow)
					idx = 1 + (c % 15);
				else if (sw) {
					/* exact-window line: slot = fine count,
					 * so each fine count shows its ONE true
					 * ramp color -- the real depth gain */
					idx = fine - slo2 + 1;
					if (idx < 1)
						idx = 1;
					if (idx > 15)
						idx = 15;
				} else {
					i = g_fmap[fine];
					idx = 1 + (i >> 2);
					if (g_dither
					    && (i & 3) > bay4[((y & 1) << 1) | (x & 1)])
						idx++;
					if (idx > 15)
						idx = 15;
				}
				if (p == 1) {	/* final pass: single-nibble RMW */
					if (x & 1)
						g_row[x >> 1] = (g_row[x >> 1] & 0xF0) | idx;
					else
						g_row[x >> 1] = (g_row[x >> 1] & 0x0F) | (idx << 4);
				} else {	/* p even, x even: whole bytes */
					b = (idx << 4) | idx;
					for (i = x >> 1; i < (x + p) >> 1; i++)
						g_row[i] = b;
				}
				cr = cr + stepp;
			}
			for (r = 0; r < p; r++) {
				row = y + r;
				if (row > ylim)
					break;
				g_off = row * 160;
				shr_putrow();
				if (mirror && row >= 1 && row <= 99) {
					g_off = (200 - row) * 160;
					shr_putrow();
				}
			}
			if (hit)
				xorcross();	/* redraw over the fresh rows */
			/* Keys work DURING the render: arrows move the
			 * live crosshair, 'p' recolors in place; q/ESC/f/j/Enter
			 * interrupt -- the caller acts on the returned key. */
			k = pollgetkey();
			if (k == 'p')
				cyclepal();
			else if (k == 'q' || k == K_ESC || k == 'f')
				return k;
			else if (k == 'h' || k == '?')
				return k;
			else if (k == '3' && !g_rainbow)
				return k;
			else if (k == 'j' && g_fmode == 0)
				return k;
			else if (k == K_ENTER && v_step > 1L)
				return k;
			else if (k == K_SLT)                    movecross(-1, 0);
			else if (k == K_SRT)                    movecross(1, 0);
			else if (k == K_SUP)                    movecross(0, -1);
			else if (k == K_SDN)                    movecross(0, 1);
			else if (k == K_LEFT  || k == 'H')      movecross(-8, 0);
			else if (k == K_RIGHT || k == 'L')      movecross(8, 0);
			else if (k == K_UP    || k == 'K')      movecross(0, -8);
			else if (k == K_DOWN  || k == 'J')      movecross(0, 8);
		}
	}
	return 0;
}

/* THE SUPER HI-RES SCREEN IS THE PHYSICAL MACHINE, and there is exactly one.
 * fractal claims it with scr_suspend() and paints bank $01 directly, so run
 * from anywhere but the console it scribbles over a display its user cannot
 * see while reading keys that are not theirs -- the drawing half of the same
 * split apple/fgx#151 is about, except that no amount of routing fixes it:
 * there is no per-terminal framebuffer to route to.
 *
 * So it refuses rather than routes.  A virtual console is refused too: the VCs
 * share the one SHR screen, so drawing from ttyv1 clobbers whatever is on it.
 *
 * THE COMPUTE-ONLY MODES ARE NOT GATED.  --sum/--sumasm* print a checksum and
 * touch no screen; they are how the goldens compare against the host oracle,
 * and gating them would make fractal untestable anywhere but an interactive
 * console.  Hence the check lives here in the drawing path and not in main().
 */
static int
console_only()
{
	int	fd;
	char	*t;
	int	ok;

	/* THE CONTROLLING TERMINAL, not fd 0 or fd 1.  Redirection moves those,
	 * and the question here is which SESSION this is, not where its bytes
	 * go -- `fractal < /dev/null' from the console is still someone sitting
	 * at the console.  /dev/tty is the device that answers exactly that
	 * question (2.11BSD tty_tty.c, added for apple/fgx#151). */
	fd = open("/dev/tty", 2);
	if (fd < 0) {
		fprintf(stderr, "fractal: no controlling terminal\n");
		return 0;
	}
	t = ttyname(fd);
	ok = (t != (char *)0 && strcmp(t, "/dev/console") == 0);
	if (!ok)
		fprintf(stderr, "fractal: needs the physical console, not %s\n",
			t != (char *)0 ? t : "this terminal");
	close(fd);
	return ok;
}

int do_draw()
{
	long ccr, cci, lx, ly, s_cr0, s_ci0, s_step;
	int k, done, dx, dy, s_maxit;

	if (!console_only())
		return 1;

	g_fmode = 0;
	sethome();			/* centered full-set view, window on (-0.5, 0) */

	mand_build();			/* quarter-square table (add-only) */
	load_upal();			/* /etc/fractal.pal -> cycle slot 5 */
	load_font();			/* console font, for the h/? help box */
	scr_suspend();			/* claim the screen: console stops flushing */
	shr_go320();			/* 320 mode */
	set_palette();

	/* Clear the frame: leftover 640-mode console text chunked through the
	 * 320 palette looks like garbage under the first chunky pass. Zoom
	 * re-renders skip this -- the old image morphs into the new one. */
	for (k = 0; k < 160; k++)
		g_row[k] = 0;
	for (k = 0; k < 200; k++) {
		g_off = k * 160;
		shr_putrow();
	}

	done = 0;
	g_cx = 160;			/* sane zoom target even mid-first-render */
	g_cy = 100;
	s_cr0 = v_cr0;			/* mandel view to restore after julia */
	s_ci0 = v_ci0;
	s_step = v_step;
	s_maxit = v_maxit;
	while (!done) {
		g_maxit = v_maxit;
		g_cx = 160;		/* each render: crosshair re-centers, hidden */
		g_cy = 100;		/* (pass 1 rewrites every row, wiping any */
		g_cvis = 0;		/* stale crosshair pixels) */
		k = render();		/* 0 = completed; else the interrupting key */
		if (k == 0) {
			shr_done();	/* headless capture marker; a crosshair
					 * summoned mid-render stays where it is */
			for (;;) {	/* crosshair phase: movement + 'p'; action
					 * keys fall through to the handler below */
				k = getkey();
				if (k == 'q' || k == K_ESC || k == 'f')
					break;
				if (k == 'h' || k == '?')
					break;
				if (k == '3' && !g_rainbow)
					break;
				if (k == 'j' && g_fmode == 0)
					break;
				if (k == K_ENTER) {
					if (v_step <= 1L)
						continue;	/* max zoom: inert */
					break;
				}
				if (k == 'p') {
					cyclepal();	/* instant recolor */
					continue;
				}
				/* arrows = 1px fine; Ctrl-arrows/HJKL = 8px */
				dx = 0;
				dy = 0;
				if (k == K_SLT)         dx = -1;
				else if (k == K_SRT)    dx = 1;
				else if (k == K_SUP)    dy = -1;
				else if (k == K_SDN)    dy = 1;
				else if (k == K_LEFT  || k == 'H') dx = -8;
				else if (k == K_RIGHT || k == 'L') dx = 8;
				else if (k == K_UP    || k == 'K') dy = -8;
				else if (k == K_DOWN  || k == 'J') dy = 8;
				if (dx == 0 && dy == 0)
					continue;	/* unknown key: no flicker */
				movecross(dx, dy);
			}
		}
		/* Action keys, from mid-render or the crosshair phase alike. */
		if (k == K_ESC && g_fmode == 1) {
			g_fmode = 0;		/* julia: back to the saved mandel */
			v_cr0 = s_cr0;
			v_ci0 = s_ci0;
			v_step = s_step;
			v_maxit = s_maxit;
		} else if (k == K_ESC || k == 'q') {
			done = 1;
		} else if (k == 'f') {
			/* cycle fractal type: mandel -> tricorn -> ship -> cubic
			 * -> mandel (julia only via 'j') */
			if (g_fmode == 0)      g_fmode = 2;
			else if (g_fmode == 2) g_fmode = 3;
			else if (g_fmode == 3) g_fmode = 4;
			else                   g_fmode = 0;
			sethome();
		} else if (k == 'j' && g_fmode == 0) {
			/* julia of the point under the crosshair; save the mandel
			 * view so ESC comes back to it */
			s_cr0 = v_cr0;
			s_ci0 = v_ci0;
			s_step = v_step;
			s_maxit = v_maxit;
			lx = g_cx;
			ly = g_cy;
			g_jcr = v_cr0 + lx * v_step;
			g_jci = v_ci0 + ly * v_step;
			g_fmode = 1;
			sethome();
		} else if (k == K_ENTER && v_step > 1L) {
			lx = g_cx;
			ly = g_cy;
			ccr = v_cr0 + lx * v_step;	/* c under the crosshair */
			cci = v_ci0 + ly * v_step;
			v_step = v_step >> 1;		/* 6 -> 3 -> 1 */
			v_cr0 = ccr - 160L * v_step;
			v_ci0 = cci - 100L * v_step;
			v_maxit = v_maxit + 16;		/* deeper view, more iters */
		} else if (k == 'h' || k == '?') {
			do_help();	/* modal box; the loop re-renders after */
		} else if (k == '3' && !g_rainbow) {
			do_show3200();	/* scanline-IRQ showcase; re-render after */
		}
	}
	scr_restore();			/* release the screen, repaint the console */
	return 0;
}

/* True 3200-color Mandelbrot. Each scanline gets its OWN 16-color palette,
 * range-fit across that line's iteration span in a global cycling-rainbow
 * spectrum, so different lines use different colors (up to 200x16 = 3200 on
 * screen). Each line's palette is staged into GFX_PALTAB at its calibrated
 * visible-$C02E slot (visible range 127..223 measured on MAME); the kernel's VGC
 * scanline-interrupt engine reloads hw palette 0 per scanline from there.
 * Higher MAXIT than the static --draw (more iteration levels = more colors) and
 * the cycling hue keeps the fast-escape exterior from collapsing to flat red. */
#define MAXIT3200 96
int do_draw3200()
{
	long cr0, ci0, step, cr, ci;
	int x, y, c, idx, lo, hi, i, itval, rgb, my, span;

	if (!console_only())
		return 1;

	cr0 = -1216L;			/* centered view (same as do_draw) */
	ci0 = -600L;
	step = 6L;

	mand_build();
	g_maxit = MAXIT3200;
	scr_suspend();
	shr_go320();
	set_palette();			/* palette 0 = tier-1 colors during the ~30s compute */

	ci = ci0;
	for (y = 0; y <= 100; y++) {
		lo = 999; hi = 0;	/* min/max of ESCAPING pixels on this line */
		cr = cr0;
		for (x = 0; x < 320; x++) {
			g_cr = cr;
			g_ci = ci;
			c = mand_asm();
			g_iter[x] = c;
			if (c < MAXIT3200) {
				if (c < lo) lo = c;
				if (c > hi) hi = c;
			}
			cr = cr + step;
		}
		if (hi < lo) hi = lo;
		span = hi - lo;
		/* Palette: 0 = interior black; 1..15 = the GLOBAL cycling spectrum
		 * color(c) = rainbow((c*5)&255). When the line's span fits (<=14 distinct
		 * counts, most of the exterior), slot 1+(c-lo) holds exactly color(c) --
		 * independent of lo, so a given count is the SAME color on every line (no
		 * stripes). Wide boundary lines (span>14) fall back to a range-fit. */
		g_pal[0] = 0; g_pal[1] = 0;
		for (i = 1; i < 16; i++) {
			if (span <= 14)
				itval = lo + (i - 1);			/* exact local */
			else
				itval = (MAXIT3200 * (i - 1)) / 14;	/* GLOBAL fit (line-independent) */
			rgb = rainbow((itval * 5) & 255);
			g_pal[i * 2] = (((rgb >> 4) & 15) << 4) | (rgb & 15);
			g_pal[i * 2 + 1] = (rgb >> 8) & 15;
		}
		g_palv = 127 + (y * 96) / 199;	/* this line's visible-$C02E slot */
		gfx_pset();
		if (y >= 1 && y <= 99) {		/* mirror row shares the palette */
			my = 200 - y;
			g_palv = 127 + (my * 96) / 199;
			gfx_pset();
		}
		/* pixels: interior -> 0, else quantize the escape count into 1..15 */
		for (x = 0; x < 160; x++)
			g_row[x] = 0;
		for (x = 0; x < 320; x++) {
			c = g_iter[x];
			if (c >= MAXIT3200)
				idx = 0;
			else if (span <= 14)
				idx = 1 + (c - lo);		/* exact: slot i holds color(c) */
			else
				idx = 1 + (c * 14) / MAXIT3200;	/* GLOBAL fit (line-independent) */
			if (idx > 15) idx = 15;
			if (x & 1)
				g_row[x >> 1] |= idx;
			else
				g_row[x >> 1] = idx << 4;
		}
		g_off = y * 160;
		shr_putrow();
		if (y >= 1 && y <= 99) {
			g_off = (200 - y) * 160;
			shr_putrow();
		}
		ci = ci + step;
	}
	shr_done();

	/* Hand the per-scanline palette reloads to the kernel's VGC scanline-
	 * interrupt engine: arm it (installs the handler, sets SCB bit 6, enables
	 * VGCINT), then just wait for a key. On each scanline IRQ the kernel reloads
	 * hw palette 0 from GFX_PALTAB[$C02E] -- hardware-timed (no jitter),
	 * cooperative with multitasking (no SEI freeze, no beam-poll spin). */
	scr_arm();
	waitkey();
	scr_disarm();			/* stop the engine + restore the console (640) */
	return 0;
}

/* Same tile as do_sum, but computed by the asm quarter-square mand_asm.
 * Must print the identical GOLDEN_TILE checksum (proves the asm == the oracle). */
int do_sumasm(cr0, ci0, step, w, h, maxit)
long cr0, ci0, step;
int w, h, maxit;
{
	long sum, cr, ci;
	int px, py, v;

	mand_build();
	g_maxit = maxit;
	sum = 5381;
	ci = ci0;
	for (py = 0; py < h; py++) {
		cr = cr0;
		for (px = 0; px < w; px++) {
			g_cr = cr;
			g_ci = ci;
			v = mand_asm();
			sum = ((sum << 5) + sum) + v;
			cr = cr + step;
		}
		ci = ci + step;
	}
	printf("ITSUM=%ld\n", sum);
	shr_done();		/* exit marker: lets timing tests end exactly here */
	return 0;
}

int main(argc, argv)
int argc;
char **argv;
{
	if (argc >= 2 && strcmp(argv[1], "--nodither") == 0) {
		g_dither = 0;
		return do_draw();
	}
	if (argc >= 2 && strcmp(argv[1], "--dither") == 0)
		return do_draw();	/* the default */
	if (argc >= 2 && strcmp(argv[1], "--rainbow") == 0) {
		g_rainbow = 1;		/* mod-15 cycling colorize */
		g_palidx = 2;		/* start the cycle on the rainbow palette */
		return do_draw();
	}
	if (argc >= 2 && strcmp(argv[1], "--sum") == 0)
		return do_sum(-1024L, -307L, 6L, 48, 30, 64);   /* GOLDEN_TILE */
	if (argc >= 2 && strcmp(argv[1], "--sumasm") == 0)
		return do_sumasm(-1024L, -307L, 6L, 48, 30, 64);   /* asm == oracle */
	/* GOLDEN_TILE2 covers the whole cardioid + period-2 bulb, so --sumasm2
	 * exercises the asm interior shortcut on-device: it must still print the
	 * plain-iteration checksum (shortcut is value-preserving). */
	if (argc >= 2 && strcmp(argv[1], "--sum2") == 0)
		return do_sum(-768L, -384L, 16L, 96, 48, 64);
	if (argc >= 2 && strcmp(argv[1], "--sumasm2") == 0)
		return do_sumasm(-768L, -384L, 16L, 96, 48, 64);
	/* Per-mode asm goldens vs the host oracle (fractal_ref --sum-*). */
	if (argc >= 2 && strcmp(argv[1], "--sumasmT") == 0) {
		g_fmode = 2;
		return do_sumasm(-768L, -384L, 16L, 96, 48, 64);
	}
	if (argc >= 2 && strcmp(argv[1], "--sumasmS") == 0) {
		g_fmode = 3;
		return do_sumasm(-768L, -384L, 16L, 96, 48, 64);
	}
	if (argc >= 2 && strcmp(argv[1], "--sumasmC") == 0) {
		g_fmode = 4;
		return do_sumasm(-640L, -400L, 16L, 80, 50, 64);
	}
	if (argc >= 2 && strcmp(argv[1], "--sumasmJ") == 0) {
		g_fmode = 1;
		g_jcr = -205;		/* classic c = -0.4 + 0.6i */
		g_jci = 307;
		return do_sumasm(-960L, -600L, 16L, 120, 75, 64);
	}
	if (argc >= 2 && strcmp(argv[1], "--vcnt") == 0) {
		/* Measure the VGC vertical-counter range + resolution (how many
		 * distinct $C02E values per frame) to decide the 3200 approach. */
		int vmin, vmax, vvmin, vvmax, v, i, vbl;
		vmin = 999; vmax = 0; vvmin = 999; vvmax = 0;
		for (i = 0; i < 30000; i++) {
			v = rd_vcnt();
			vbl = rd_vbl();
			if (v < vmin) vmin = v;
			if (v > vmax) vmax = v;
			if ((vbl & 128) == 0) {		/* not blanking = visible */
				if (v < vvmin) vvmin = v;
				if (v > vvmax) vvmax = v;
			}
		}
		printf("VCNT all=%d..%d vis(vbl0)=%d..%d\n", vmin, vmax, vvmin, vvmax);
		return 0;
	}
	if (argc >= 2 && strcmp(argv[1], "--3200test") == 0)
		return do_gfx3200test();
	if (argc >= 2 && strcmp(argv[1], "--3200") == 0)
		return do_draw3200();		/* true 3200-color Mandelbrot */
	if (argc < 2 || strcmp(argv[1], "--draw") == 0)
		return do_draw();

	fputs("usage: fractal [--draw | --rainbow | --nodither | --sum]\n", stderr);
	fputs("keys: arrows move (HJKL/ctrl-arrows 8px), enter zoom, p palette,\n", stderr);
	fputs("      f fractal type, j julia of crosshair, esc back/exit, q quit\n", stderr);
	return 1;
}
