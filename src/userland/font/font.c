/* FGX-Origin: original -- FGX code.  Nothing here derives from the Regents'
 * work.  It NAMES 2.11BSD only to say why the path is not case-folded, which
 * is a fact about the root filesystem rather than a port.
 */
/* font(1) -- list, load, or revert the console bitmap font.
 * FGX-native C rewrite (H2 roadmap), replacing the hand-asm font.s;
 * output matches it (active entry marked "* ", others indented).
 *
 * Usage:
 *   font              list /lib/fonts/*.FNT and "default", mark active
 *   font default      revert to the built-in default font
 *   font NAME         load NAME.fnt from the font dir
 *
 * THE NAME IS USED AS GIVEN.  The root is 2.11BSD and case-sensitive, and the
 * fonts are staged lowercase, so a name folded to either case is a name that
 * may not be there.  `font' with no argument lists what is on the volume and
 * `fnt_short' lowercases only for the ACTIVE-name comparison, which is a
 * comparison and not a path.
 */
#include <sys/dir.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#define FONTDIR "/lib/fonts"

static char cur_name[32];
static char shortname[32];
static char path_buf[64];

static int lower(c)
	int	c;
{
	if (c >= 'A' && c <= 'Z')
		return c + 32;
	return c;
}

/* entry ends in ".FNT" (any case)?  If so copy the stripped, lowercased
 * basename into shortname and return 1. */
static int fnt_short(name)
	char	*name;
{
	int len, i;

	len = strlen(name);
	if (len < 5 || len - 4 >= (int)sizeof(shortname))
		return 0;
	if (name[len - 4] != '.' ||
	    lower(name[len - 3]) != 'f' ||
	    lower(name[len - 2]) != 'n' ||
	    lower(name[len - 1]) != 't')
		return 0;
	for (i = 0; i < len - 4; i++)
		shortname[i] = lower(name[i]);
	shortname[i] = 0;
	return 1;
}

static int do_list()
{
	DIR *dp;
	struct direct *de;

	fontname(cur_name, sizeof(cur_name));
	/* empty kernel name = built-in default (nothing loaded yet); the
	 * literal gets the star, file entries only match a LOADED name */
	printf("%s default\n",
	       (cur_name[0] == 0 || strcmp(cur_name, "default") == 0)
	           ? "*" : " ");
	dp = opendir(FONTDIR);
	if (dp == NULL)
		return 0;               /* no /lib/fonts — quietly done */
	while ((de = readdir(dp)) != NULL) {
		if (!fnt_short(de->d_name))
			continue;
		printf("%s %s\n",
		       strcmp(cur_name, shortname) == 0 ? "*" : " ",
		       shortname);
	}
	closedir(dp);
	return 0;
}

int main(argc, argv)
	int	argc;
	char	**argv;
{
	int i, j;

	if (argc < 2)
		return do_list();
	if (strcmp(argv[1], "default") == 0) {
		fontrevert();
		return 0;
	}
	/* /lib/fonts/<arg>.fnt */
	strcpy(path_buf, FONTDIR);
	strcat(path_buf, "/");
	j = strlen(path_buf);
	for (i = 0; argv[1][i] && j < (int)sizeof(path_buf) - 6; i++)
		path_buf[j++] = argv[1][i];
	path_buf[j] = 0;
	strcat(path_buf, ".fnt");
	if (fontload(path_buf) != 0) {
		fprintf(stderr, "font: %s: load failed (errno %d)\n",
			path_buf, errno);
		return 1;
	}
	return 0;
}
