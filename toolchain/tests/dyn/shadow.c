/* A dynamic link's fixture (shared libc SP3 step 3): an initialised
 * definition of a libc data export shadows it. */
int optind = 1;
extern char *optarg;
int
main()
{
    return optind + (optarg != 0);
}
