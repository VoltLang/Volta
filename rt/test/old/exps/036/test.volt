//T compiles:yes
//T retval:24
module test;

int foo(int x = __LINE__)
{
	return x;
}

int main()
{
	return foo() + foo();
}

