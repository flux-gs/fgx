/* M22/P3-2.2: int+ptr must scale the INT side.  The historical arm
 * (N_ADD_IPLUSP, transcribed from the pre-AST grammar) scaled the
 * POINTER OFFSET instead: `p = i + arr` compiled as i + 2*arr for int
 * elements — invisible for char* (stride 1), a live miscompile for any
 * wider pointee.  Fixed by the P3-2.2 FPR arm (the int in A is scaled,
 * the pointer offset stays in its register). */
int arr[5];
long larr[3];

int
main()
{
	int i;
	int *p;
	long *lp;
	arr[3] = 40;
	i = 3;
	p = i + arr;               /* must be &arr[3] */
	if (*p != 40) return 1;
	if (p - arr != 3) return 2;
	larr[2] = 100000L;
	i = 2;
	lp = i + larr;             /* 4-byte stride */
	if (*lp != 100000L) return 3;
	if (2 + arr != arr + 2) return 4;   /* commutativity */
	return 42;
}
