/* C-1: do-while runs the body ONCE even when the condition is false on
 * entry (the distinguishing semantic vs while).  Returns 7. */
int main(){ int n; n=0; do { n=n+7; } while (n<0); return n; }
