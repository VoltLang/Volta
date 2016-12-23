//T compiles:yes
//T retval:10
module test;

int foo(int i)
{
	return i + 1;
}

int bar(int i)
{
	return i + 2;
}

int baz(int a, int b)
{
	return b;
}

int main()
{
	int gah = 2;
	return gah.foo() + gah.bar() + gah.baz(3);
}

