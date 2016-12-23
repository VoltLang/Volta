//T compiles:yes
//T retval:41
module test;

void foo(const(char*)**)
{
        return;
}

int main()
{
        const(char)** ptr;
        foo(&ptr);
        return 41;
}
