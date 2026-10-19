/* Chained struct-member assignment as an expression: `a.f = b.f = v` (the
 * tr(1) port surfaced this; parse_assign now handles a struct-member LHS as a
 * chain link).  s1/s2 globals with int + char* fields; the int chains feed the
 * return, the char* chain exercises the ISPTR member-store path in codegen. */
struct string { int last, max; char *p; } s1, s2;
int main(){
    s1.last = s2.last = 7;
    s1.max  = s2.max  = 3;
    s1.p = s2.p = "x";
    return s1.last + s2.last + s1.max + s2.max;   /* 7+7+3+3 = 20 */
}
