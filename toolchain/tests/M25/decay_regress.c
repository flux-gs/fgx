/* Regression: char *arr[] (now derived ARY<PTR<CHAR>>) still indexes.
 * arr[1] == "*", *arr[1] == 42. */
char *arr[] = {"x", "*", "z"};
int main(void){ return *arr[1]; }
