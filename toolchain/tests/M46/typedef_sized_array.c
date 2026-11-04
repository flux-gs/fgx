/* A typedef that names an array of known size, as 2.11BSD's pdp/seg.h
 * declares `typedef struct segm_reg mapinfo[2];'.  A declaration through
 * the name gets the array type, and a parameter declared with it is a
 * pointer.  Returns 42. */
typedef int vec3[3];
typedef struct pt {
	int x, y;
} pair[2];

vec3 g;
pair gp;

int
third(a)
	vec3 a;
{
	a[2] = 5;
	return (sizeof(a) == sizeof(int *));
}

int main()
{
	vec3 v;
	int r;

	if (sizeof(vec3) != 6 || sizeof(pair) != 8 || sizeof(g) != 6)
		return (1);
	v[2] = 10;
	g[1] = 11;
	gp[1].y = 12;
	gp[0].x = 3;
	if (!third(v) || v[2] != 5)
		return (2);
	r = v[2] + g[1] + gp[1].y + gp[0].x + 1;
	return (r + sizeof(gp[0]) * 2 + 2);
}
