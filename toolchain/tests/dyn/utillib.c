/* A dynamic link against libutil.so (shared libc SP5): logwtmp is
 * libutil's (2.11BSD usr.lib/libutil/logwtmp.c). */
main()
{
    logwtmp("ttyp0", "", "");
    return 0;
}
