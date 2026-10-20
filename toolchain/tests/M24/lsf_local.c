/* B-4: long field in a function-local struct. Returns 42. */
struct u { long n; int k; };
int main(){ struct u a; a.k=0; a.n = 42L; return (int)a.n; }
