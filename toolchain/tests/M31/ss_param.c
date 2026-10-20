/* Params stay on the hardware stack (calling convention unchanged) while locals
 * live on the software stack.  Under --soft-stack the param offsets drop the
 * FRAMESIZE term (no local frame between SP and the return address), so `calc`
 * reads a/b/c at 7,S / 5,S / 3,S alongside its soft-stack locals s (int) and t
 * (long).  -> 42. */
int calc(int a, int b, int c)
{
	int  s;
	long t;

	s = a + b;
	t = c;
	return s + (int)t;
}

int main(void) { return calc(10, 20, 12); }   /* 30 + 12 = 42 */
