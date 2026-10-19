/* E-1: defined() with && and !.  A defined, B not -> true arm -> 3. */
#define A 1
int main(){
#if defined(A) && !defined(B)
    return 3;
#else
    return 1;
#endif
}
