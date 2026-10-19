/* D-1: local struct brace init.  p.x+p.y = 40+2 = 42. */
struct s { int x; int y; };
int main(){ struct s p = {40, 2}; return p.x + p.y; }
