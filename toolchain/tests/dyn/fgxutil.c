/* A dynamic link against libfgx.so and libutil.so together (shared libc
 * SP5): spawnx and logout each reach their library's block table, so the
 * program names both tables. */
char *av[] = { "true", 0 };

main()
{
    spawnx("/bin/true", av, (char *)0);
    logout("ttyp0");
    return 0;
}
