//T compiles:no
module test;

import watt.io;

class Parent
{
	int y;
}

class Derived : Parent
{
	this(int x)
	{
		y = x;
	}
}

int foo(Parent[] a)
{
	return a[0].y + cast(int) a.length;
}

int main()
{
	Parent[] a = [new Derived(3)];
	return foo(a);
}
