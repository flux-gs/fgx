/* E-1: #if/#elif/#else chain.  M==2 selects the #elif arm -> 20. */
#define M 2
int main(){
#if M == 1
    return 10;
#elif M == 2
    return 20;
#else
    return 30;
#endif
}
