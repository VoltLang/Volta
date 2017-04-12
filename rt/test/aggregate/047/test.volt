//T default:no
//T macro:expect-failure
//T check:attempts to subclass
module test;

final class Parent
{
	fn a() i32
	{
		return 0;
	}
}

class Child : Parent
{
}

fn main() i32
{
	p: Parent = new Parent();
	return p.a();
}
