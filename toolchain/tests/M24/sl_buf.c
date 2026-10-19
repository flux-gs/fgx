/* C-3: static char buffer (the recipe's file-scope-global workaround,
 * now writable as a real static local).  Returns 65 ('A'). */
char *getbuf(){ static char buf[8]; buf[0]=65; return buf; }
int main(){ char *p; p=getbuf(); return p[0]; }
