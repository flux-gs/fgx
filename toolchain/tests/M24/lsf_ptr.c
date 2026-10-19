/* B-4: store/load a long field via a struct pointer (p->sz). Returns 50. */
struct t { int x; long sz; };
void setit(struct t *p){ p->sz = 50L; }
int main(){ struct t st; st.x=0; setit(&st); return (int)st.sz; }
