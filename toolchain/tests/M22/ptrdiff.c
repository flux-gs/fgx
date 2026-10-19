/* ptrdiff.c — pointer subtraction `p - q` returns the ELEMENT COUNT (byte
 * difference / sizeof element), for power-of-2 strides (int* = 2,
 * struct{int,int}* = 4) AND non-power-of-2 (struct{int,int,char}* = 6, via a
 * signed 16-bit divide).  fcc previously divided only for stride 2, so stride-4
 * and stride-6 pointer subtraction returned a raw BYTE count.  -> 42. */
struct p2 { int x; int y; };            /* stride 4 (power of 2) */
struct p3 { int a; int b; char c; };    /* stride 6 (non-power-of-2) */
struct p2 g4[4];
struct p3 g6[4];
int gi[8];

int main(void)
{
	struct p2 *a4 = g4, *b4 = g4 + 3;
	struct p3 *a6 = g6, *b6 = g6 + 3;
	int *ai = gi, *bi = gi + 5;
	if (b4 - a4 != 3) return 1;    /* stride 4: 2 LSRs */
	if (b6 - a6 != 3) return 2;    /* stride 6: divs16 */
	if (bi - ai != 5) return 3;    /* stride 2: 1 LSR */
	return 42;
}
