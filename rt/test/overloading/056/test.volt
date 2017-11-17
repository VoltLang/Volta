module test;

class Grandparent
{
	fn getNumber() i32
	{
		return 12;
	}
}

class Parent : Grandparent
{
}

class Child : Parent
{
	override fn getNumber() i32
	{
		return super.getNumber() + 1;
	}
}

fn main() i32
{
	obj := new Child();
	return obj.getNumber() - 13;
}
