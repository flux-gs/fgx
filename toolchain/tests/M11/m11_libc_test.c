int strlen(char *s);
int strcmp(char *a, char *b);
int printf(char *fmt, ...);

int main()
{
    int n;
    int eq;
    int rc;

    n  = strlen("hello");
    eq = strcmp("eq", "eq");

    printf("n=%d eq=%d\n", n, eq);

    rc = n * 8 + 2;
    return rc;
}
