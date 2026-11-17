/* expect: incomplete */
struct s f();
int h() { f(); return 0; }
struct s { int a, b; };
