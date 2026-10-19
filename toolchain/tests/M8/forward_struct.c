struct list;

struct list {
    struct list *next;
    int val;
};

int main()
{
    struct list a;
    struct list b;
    struct list *p;
    a.val  = 20;
    b.val  = 22;
    a.next = &b;
    p = a.next;
    return a.val + p->val;
}
