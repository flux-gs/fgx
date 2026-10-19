/* E-1: #if with a constant expression over a macro value.  VER>=5 -> 9. */
#define VER 5
int main(){
#if VER >= 5
    return 9;
#else
    return 1;
#endif
}
