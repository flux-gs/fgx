/* calloc(3): malloc + zero (kmalloc does not clear). */
char *calloc(int n, int size)
{
    char *p = malloc(n * size);

    if (p != 0)
        memset(p, 0, n * size);
    return p;
}

/* strdup(3): malloc + copy. */
char *strdup(char *s)
{
    char *p = malloc(strlen(s) + 1);

    if (p != 0)
        strcpy(p, s);
    return p;
}

