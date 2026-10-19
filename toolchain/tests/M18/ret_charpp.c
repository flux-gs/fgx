/* M18: char ** function RETURN type (2.11BSD telnet getnextcmd()).  fcc's
 * return-type parser consumed only ONE '*' (LT_CHAR_PTR); a second star hit
 * "expected function name".  Fixed: count all stars via type_for_decl. */
char *tab[2];
char **fill(a, b)
	char *a;
	char *b;
{
	tab[0] = a;
	tab[1] = b;
	return tab;
}
int main()
{
	char **m;
	m = fill((char *)"x", (char *)"yz");
	return m[0][0] + m[1][1];   /* 'x'(120) + 'z'(122) = 242 */
}
