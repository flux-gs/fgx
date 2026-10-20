/* color(1) — set default foreground / background / border color.
 * FGX-native C rewrite (H2 roadmap), replacing the hand-asm color.s.
 * Pure syscall tool: SYS_SETPAL rewrites palette 0's fg/bg slots to a
 * 12-bit RGB, SYS_BORDER sets the IIgs border (16 hardware colors).
 *
 * Usage:
 *   color -fg <name>          set screen foreground to a named ANSI color
 *   color -bg <name>          set screen background
 *   color -bd <name>          set IIgs border color
 *   color -fg|-bg -x RRGGBB   24-bit hex; each channel truncated to its
 *                             high nibble (SHR palette is 4 bits/channel)
 */
#include <stdio.h>
#include <string.h>

#define MODE_NONE 0
#define MODE_FG   1
#define MODE_BG   2
#define MODE_BD   3

struct centry { char *name; int val; };

/* xterm/VGA-style ANSI names -> 12-bit RGB (blue = IIgs system #000099). */
static struct centry ansi[] = {
	{ "black",         0x0000 }, { "red",           0x0A00 },
	{ "green",         0x00A0 }, { "yellow",        0x0AA0 },
	{ "blue",          0x0009 }, { "magenta",       0x0A0A },
	{ "cyan",          0x00AA }, { "white",         0x0AAA },
	{ "gray",          0x0555 }, { "brightred",     0x0F55 },
	{ "brightgreen",   0x05F5 }, { "brightyellow",  0x0FF5 },
	{ "brightblue",    0x055F }, { "brightmagenta", 0x0F5F },
	{ "brightcyan",    0x05FF }, { "brightwhite",   0x0FFF },
	{ 0, 0 }
};

/* ANSI names -> the 4-bit IIgs hardware border color. */
static struct centry hw[] = {
	{ "black",  0 }, { "red",     1 }, { "green",  4 }, { "yellow", 13 },
	{ "blue",   2 }, { "magenta", 3 }, { "cyan",   7 }, { "white",  10 },
	{ "gray",   5 }, { "brightred", 9 }, { "brightgreen", 12 },
	{ "brightyellow", 13 }, { "brightblue", 6 }, { "brightmagenta", 11 },
	{ "brightcyan", 14 }, { "brightwhite", 15 },
	{ 0, 0 }
};

static int usage()
{
	fputs("usage: color -fg|-bg|-bd <name>\n", stderr);
	fputs("       color -fg|-bg -x RRGGBB\n", stderr);
	return 1;
}

static int lookup(tab, name, valp)
	struct centry	*tab;
	char	*name;
	int	*valp;
{
	int i;

	for (i = 0; tab[i].name; i++) {
		if (strcmp(tab[i].name, name) == 0) {
			*valp = tab[i].val;
			return 0;
		}
	}
	return -1;
}

static int hexnib(c)
	int	c;
{
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

int main(argc, argv)
	int	argc;
	char	**argv;
{
	int mode, have_rgb, rgb12, i, v, hi;
	char *name;

	mode = MODE_NONE;
	have_rgb = 0;
	rgb12 = 0;
	name = 0;

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-fg") == 0)      mode = MODE_FG;
		else if (strcmp(argv[i], "-bg") == 0) mode = MODE_BG;
		else if (strcmp(argv[i], "-bd") == 0) mode = MODE_BD;
		else if (strcmp(argv[i], "-x") == 0) {
			i++;
			if (i >= argc || strlen(argv[i]) != 6)
				return usage();
			/* RRGGBB -> high nibble of each channel = rgb12 */
			rgb12 = 0;
			for (v = 0; v < 3; v++) {
				hi = hexnib(argv[i][v * 2]);
				if (hi < 0 || hexnib(argv[i][v * 2 + 1]) < 0)
					return usage();
				rgb12 = (rgb12 << 4) | hi;
			}
			have_rgb = 1;
		} else
			name = argv[i];
	}

	if (mode == MODE_NONE)
		return usage();
	if (mode == MODE_BD) {
		if (have_rgb) {
			fputs("color: -bd does not accept -x (border is 16 hardware colors)\n",
			      stderr);
			return 1;
		}
		if (name == 0 || lookup(hw, name, &v) != 0) {
			fputs("color: unknown color name\n", stderr);
			return 1;
		}
		border(v);
		return 0;
	}
	if (!have_rgb) {
		if (name == 0 || lookup(ansi, name, &rgb12) != 0) {
			fputs("color: unknown color name\n", stderr);
			return 1;
		}
	}
	if (setpal(mode == MODE_FG ? 0 : 1, rgb12) != 0) {
		fputs("color: setpal failed\n", stderr);
		return 1;
	}
	return 0;
}
