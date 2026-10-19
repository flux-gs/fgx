/* B-3: char ** double-deref.  g points at "*"; p=&g; **p == '*' == 42. */
char *g = "*";
int main(void){ char **p; p = &g; return **p; }
