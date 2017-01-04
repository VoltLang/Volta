module test;


class Base
{
	val: i32;

	this()
	{
		val = 42;
	}
}

class Super : Base
{
	this(foo: i32)
	{
		// Should compile and implicitly call super();
		// But if compilation 100% garanteed to be correct
		// make sure its a error at least.
	}
}

int main()
{
	s := new Super(4512421);	
	return s.val - 42;
}
