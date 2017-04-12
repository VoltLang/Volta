module test;

abstract class Parent
{
	abstract fn a() i32;
}

final class Child : Parent
{
	final override fn a() i32
	{
		return 1;
	}
}

fn main() i32
{
	p: Parent = new Child();
	return p.a() - 1;
}
