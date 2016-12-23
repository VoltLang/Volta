//T compiles:yes
//T retval:3
module test;

void foo(const(int**)*)
{
	return;
}

void bar(const(int*)** arg)
{
	foo(arg);
}

int main()
{
	return 3;
}

