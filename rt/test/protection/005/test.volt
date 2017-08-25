//T macro:importfail
//T check:access
module test;

import a;

class A : _interface
{
	override fn foo() i32
	{
		return 0;
	}
}

fn main() i32
{
	a := new A();
	return a.foo();
}

