module test;

class Parent
{
	fn f() i32 { return 1; }
}

class Child : Parent
{
	override fn f() i32 { return 2; }
}

class GrandChild : Child
{
	override fn f() i32 { return 3; }
}

// Testing function, takes a child not grandchild.
fn func(c: Child) i32
{
	// This call doesn't get dispatched.
	return c.f();
}

fn main() i32
{
	// Create the grandchild.
	c := new GrandChild();
	return func(c) - 3;
}
