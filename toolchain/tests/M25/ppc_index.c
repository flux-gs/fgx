/* B-3: indexed read of a char ** (decayed from char *arr[]).
 * p[1] yields the char* "*"; *s == '*' == 42. */
char *words[] = {"x", "*", "z"};
int main(void){ char **p; char *s; p = words; s = p[1]; return *s; }
