/* M21: char *names[] = {...} global init + indexed-read + strlen.
 * 5 + 4 + 5 + 28 = 42. */
int strlen(char *s);

char *names[3] = {"alpha", "beta", "gamma"};

int main()
{
    int n;
    n = strlen(names[0]) + strlen(names[1]) + strlen(names[2]);
    return n + 28;
}
