/* C-2: comma in for-init and for-step.  i,j converge from (0,10); loop runs
 * while i<j stepping i++ / j--: (0,10)(1,9)(2,8)(3,7)(4,6) = 5 iterations. */
int main(){ int i; int j; int s; s=0; for(i=0,j=10; i<j; i=i+1,j=j-1){ s=s+1; } return s; }
