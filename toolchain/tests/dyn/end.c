/* refers to the linker-defined end, as sh does for its arena; odd is
   3 bytes, so the data does not end on a 4-byte boundary by chance */
extern char end[];
char odd[3] = "ab";

main()
{
	return end[0] + odd[0];
}
