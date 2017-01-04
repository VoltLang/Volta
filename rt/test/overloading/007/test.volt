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

fn foo(obj: Object) i32
{
	return 42;
}

fn foo(a: A) i32
{
	return 0;
}

fn main() i32
{
	b: B;
	return foo(b);
}
