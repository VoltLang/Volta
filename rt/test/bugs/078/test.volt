//T default:no
//T macro:expect-failure
//T check:implicitly convert
module test;

class Parent
{
	y: i32;
}

class Derived : Parent
{
	this(x: i32)
	{
		y = x;
	}
}

fn foo(a: Parent[]) i32
{
	return a[0].y + cast(i32) a.length;
}

fn main() i32
{
	a: Parent[] = [new Derived(3)];
	return foo(a);
}
