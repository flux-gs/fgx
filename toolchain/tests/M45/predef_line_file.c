/* __LINE__ and __FILE__.  K&R A.12.10: "__LINE__ A decimal constant
 * containing the current source line number.  __FILE__ A string literal
 * containing the name of the file being compiled."  A use inside a macro
 * body reports the line the macro is used on, as 2.11BSD assert() relies
 * on.  This file's name ends "file.c".  Returns 42. */
#define HERE __LINE__

char name[] = __FILE__;

int main()
{
    int n, r;

    for (n = 0; name[n] != 0; n++)
        ;
    r = 0;
    if (__LINE__ == 17) r += 10;
    if (HERE == 18) r += 20;
    if (n > 6 && name[n - 6] == 'f' && name[n - 1] == 'c') r += 12;
    return r;
}
