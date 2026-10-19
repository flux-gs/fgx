/* B-3: write-through *pp = q.  a->"A"(65), b->"*"(42); p=&a; *p=b; **p==42. */
char *a = "A";
char *b = "*";
int main(void){ char **p; p = &a; *p = b; return **p; }
