/* B-2: sizeof(union) = max member size, padded even.  max(2,4,3)=4. */
union u { int i; long l; char c[3]; };
int main(){ return sizeof(union u); }
