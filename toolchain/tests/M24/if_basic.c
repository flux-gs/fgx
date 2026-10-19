/* E-1: #if 1 selects the true arm.  Returns 42 (0 if the false arm leaked). */
int main(){
#if 1
    return 42;
#else
    return 0;
#endif
}
