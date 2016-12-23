//T compiles:no
//T retval:17
// super postfix.
module test;


class Parent
{
	int x;

	this()
	{
		return;
	}
}

class Child : Parent
{
	this(int x)
	{
		// Right now it doesn't compile,
		// not sure if we want to support this anyways.
		super.x = 17;
		return;
	}
}

int main()
{
	auto child = new Child(42);
	return child.x;
}
