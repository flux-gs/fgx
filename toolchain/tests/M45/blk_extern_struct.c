/* A block-scope extern array of structs, indexed by pointer arithmetic before
 * any file-scope declaration of it is seen, as 2.11BSD ftp's help() walks
 * `extern struct cmd cmdtab[];' with `c = cmdtab + j * lines + i'.  K&R
 * A.11.2: with no external declaration visible, "its linkage is external",
 * so the name is the program's array, and its element is the struct.
 * Returns 42. */
struct cmd {
	char	*c_name;
	int	c_val;
};

int pick(i, j)
	int i, j;
{
	extern struct cmd cmdtab[];
	register struct cmd *c;

	c = cmdtab + j * 2 + i;
	return (c->c_val);
}

struct cmd cmdtab[] = {
	{ "a", 1 }, { "b", 2 }, { "c", 30 }, { "d", 12 },
};

int main()
{
	return pick(0, 1) + pick(1, 1);
}
