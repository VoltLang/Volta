module test;

class A
{
	fn foo() i32 { return 1; }
}

fn main() i32
{
	a: A = new B();
	return a.foo();
}

private:

class B : A
{
public:
	override fn foo() i32  // test2.volt:18:11: error: function 'foo' access level differs from overridden function @ test2.volt:5:2.
	{
		return 0;
	}
}