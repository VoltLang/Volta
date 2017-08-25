//T macro:expect-failure
//T check:unidentified identifier 'x'
// Invalid super postfix.
module test;


class Parent
{
	this()
	{
		return;
	}
}

class Child : Parent
{
	this(x: i32)
	{
		super.x = 17;
		return;
	}
}

int main()
{
	auto child = new Child(42);
	return child.x;
}
