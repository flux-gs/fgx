/* expect: struct */
int main() { return early(1).x; }
struct q { int x; };
struct q early(a) int a; { struct q r; r.x = a; return (r); }
