module test;

class Parent
{
	fn contemplate() i32
	{
		return 7;
	}
}

class Child : Parent
{
	fn contemplate(ignored: i32) i32
	{
		return 12;
	}
}

fn main() i32
{
	child := new Child();
	return child.contemplate(17) - 12;
}

