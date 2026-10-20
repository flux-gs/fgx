/* M42: --libso literals.  A string literal lives in the code bank and its
 * bank is pushed with PHK; a char array initialised from a literal is a
 * writable static and stays in data (K&R A.2.6, A.8.7). */
static char *msg = "lit-ptr";
static char arr[] = "arr-init";
int strlen();
int main()
{
    arr[0] = 'A';
    return strlen("expr-lit") + strlen(msg) + arr[0] == 8 + 7 + 65 ? 42 : 1;
}
