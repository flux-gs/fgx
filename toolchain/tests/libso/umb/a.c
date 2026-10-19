static int a_count;
static char a_buf[10];
int a_get() { static int calls; calls++; return a_count + a_buf[0] + calls; }
