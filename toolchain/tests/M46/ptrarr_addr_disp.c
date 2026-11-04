/* An address plus or minus a constant as an element of an array of
 * pointers' initializer.  K&R A.7.19: "Initializers must evaluate either to
 * a constant or to the address of a previously declared external or static
 * object plus or minus a constant."  The displacement scales by the
 * pointee: iarr+3 is six bytes in.  #45 made the struct-field form work;
 * this is the array form.  Returns 42. */
char t[10];
int iarr[5];
char *tp[] = { t+4, t, &t[2], t+9-1 };
int *ip[] = { iarr+3, iarr, iarr+4-2 };

int main()
{
	t[4] = 20;
	t[2] = 10;
	t[8] = 1;
	iarr[3] = 11;
	iarr[2] = 0;
	if (tp[1] != t || ip[1] != iarr)
		return (1);
	if (ip[2] != &iarr[2] || tp[3] != &t[8])
		return (2);
	return (*tp[0] + *tp[2] + *tp[3] + *ip[0] + *ip[2]);
}
