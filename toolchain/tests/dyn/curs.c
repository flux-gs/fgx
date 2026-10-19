/* A dynamic link against libcurses (shared libc SP3 step 3): its data
 * exports, among them DA, a Merlin directive's name, as EQUs. */
extern int LINES, COLS;
extern char *DA;
int
main()
{
    return LINES + COLS + (DA != 0);
}
