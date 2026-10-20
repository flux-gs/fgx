/* Whole-struct element copy `arr[i] = arr[j]` — elvis cut.c's anonymous-buffer
 * shift (`anon[i]=anon[i-1]`) and cmd1's tag_stack shift.  Block-copies the
 * whole struct between array elements (all fields: int, char*, long) instead of
 * requiring a `.field`.  -> 42. */
struct cb { int a; char *p; long z; };
struct cb arr[4];
char *gs;

int main(void)
{
	int i;

	gs = "hi";
	for (i = 0; i < 4; i++) {
		arr[i].a = i * 10;      /* 0, 10, 20, 30 */
		arr[i].p = gs;
		arr[i].z = 100;
	}
	arr[0].z = 777;             /* mark element 0's long field */

	/* shift values up: arr[i] gets arr[i-1] (top-down so no clobber). */
	for (i = 3; i > 0; i--)
		arr[i] = arr[i - 1];

	if (arr[0].a != 0)   return 1;   /* unchanged */
	if (arr[1].a != 0)   return 2;   /* got old arr[0] */
	if (arr[2].a != 10)  return 3;   /* got old arr[1] */
	if (arr[3].a != 20)  return 4;   /* got old arr[2] */
	if (arr[1].z != 777) return 5;   /* long field copied whole */
	if (arr[1].p[0] != 'h') return 6;/* char* copied (offset+bank) */
	if (arr[3].p[1] != 'i') return 7;
	return 42;
}
