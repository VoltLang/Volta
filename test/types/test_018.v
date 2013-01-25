//T compiles:yes
//T retval:36
// Tests mutable indirection detection.
module test_018;

int a()
{
    auto tinfo = typeid(int);
    if (tinfo.mutableIndirection) {
        return 2;
    } else {
        return 4;
    }
}

int b()
{
    auto tinfo = typeid(int*);
    if (tinfo.mutableIndirection) {
        return 6;
    } else {
        return 8;
    }
}

struct StructA
{
    int a;
    int b;
}

struct StructB
{
    int a;
    int* b;
}

int c()
{
    auto tinfo = typeid(StructA);
    if (tinfo.mutableIndirection) {
        return 10;
    } else {
        return 12;
    }
}

int d()
{
    auto tinfo = typeid(StructB);
    if (tinfo.mutableIndirection) {
        return 14;
    } else {
        return 16;
    }
}

int main()
{
    return a() + b() + c() + d();
}
