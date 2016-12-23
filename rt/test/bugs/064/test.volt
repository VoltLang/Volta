//T compiles:yes
//T retval:7
module test;

int foo(string[] s...)
{
	return 7;
}

int foo(int x)
{
	return 9;
}

int main()
{
	return foo("hello", "world");
}
