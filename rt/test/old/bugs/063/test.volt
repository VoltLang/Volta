//T compiles:yes
//T retval:12
module test;

int foo(int[] a...)
{
	return 6;
}

int bar(string[] s)
{
	return 6;
}

int foo(int x)
{
	return 7;
}

int main()
{
	return foo([]) + bar([]);
}
