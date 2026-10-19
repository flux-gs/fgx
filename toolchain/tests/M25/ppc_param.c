/* B-3: pass char ** to a function and deref inside.  **q == '*' == 42. */
char *g = "*";
int deref2(char **q){ return **q; }
int main(void){ return deref2(&g); }
