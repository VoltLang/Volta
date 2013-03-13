//T compiles:yes
//T retval:12
module test_020;

enum named { a, b, c }

int doSomething(named n)
{
    if (n == named.c) {
        return 11;
    }
    return 5;
}

int main()
{
    return doSomething(named.c) + cast(int) named.b;
}
