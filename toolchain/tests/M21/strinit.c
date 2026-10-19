/* char[] = "string literal" — bytes laid into array directly,
 * NUL-terminated.  Returns 42 ('*' char).
 */
char buf[] = "*Q";

int main()
{
    return buf[0];
}
