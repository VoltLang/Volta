//T compiles:yes
//T retval:32
// More specialised function.
module test;

import core.object : Object;


class A
{
	this()
	{
		return;
	}
}

class B : A
{
	this()
	{
		return;
	}
}

int foo(Object obj)
{
	return 42;
}

int foo(A a)
{
	return 32;
}

int main()
{
	B b;
	return foo(b);
}
