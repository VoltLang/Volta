//T default:no
//T macro:expect-failure
//T check:Matching locations:
module test;

class A
{
	fn foo() i32
	{
		return 1;
	}
}

class B : A
{
	override fn foo() i32
	{
		return 2;
	}

	override fn foo() i32
	{
		return 3;
	}

	override fn foo() i32
	{
		return 4;
	}
}

fn main() i32
{
	a: A = new B();
	return a.foo();
}
