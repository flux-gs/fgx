/* expect: incomplete */
extern struct nope g;
int main() { return g.x; }
