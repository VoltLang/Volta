//T compiles:yes
//T retval:42
module test;


class Base
{
	int val;

	this()
	{
		val = 42;
	}
}

class Super : Base
{
	this(int foo)
	{
		// Should compile and implicitly call super();
		// But if compilation 100% garanteed to be correct
		// make sure its a error at least.
	}
}

int main()
{
	auto s = new Super(4512421);	
	return s.val;
}
