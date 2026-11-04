/* # and ## in macro replacement, K&R A.12.3.  cat() pastes its arguments
 * WITHOUT expanding them ("Unless the parameter in the replacement sequence
 * is preceded by #, or preceded or followed by ##, the argument tokens are
 * examined for macro calls"), so cat(x, ONE) is the identifier xONE, not
 * x1; xcat() expands first, so xcat(x, ONE) is x1.  str() makes a string of
 * its unexpanded argument, escaping a string literal inside it.  2.11BSD's
 * uipc_domain.c builds `unixdomain' this way (written with the Reiser `/ ** /'
 * idiom upstream).  Returns 42. */
#define ONE 1
#define cat(a, b) a ## b
#define xcat(a, b) cat(a, b)
#define str(x) #x
#define PASTED cat3 ## _obj

int var123 = 20;
int xONE = 15;
int x1 = 7;
int cat3_obj = 0;

static int
same(s, t)
	char *s, *t;
{
	while (*s && *s == *t)
		s++, t++;
	return (*s == *t);
}

int main()
{
	int r;

	r = cat(var, 123) + cat(x, ONE) + xcat(x, ONE);
	PASTED = 3;
	if (!same(str(abc), "abc"))
		return (1);
	if (!same(str(ONE), "ONE"))
		return (2);
	if (!same(str(a "q\n" b), "a \"q\\n\" b"))
		return (3);
	return (r + cat3_obj - 3);
}
