/* B-5: array of int pointers (ARY<PTR<INT>>).  arr[1] = &y, *arr[1] == 42. */
int x = 20, y = 42, z = 7;
int *arr[] = {&x, &y, &z};
int main(void){ return *arr[1]; }
