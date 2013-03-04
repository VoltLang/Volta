//T compiles:yes
//T retval:6
// Properties handled correctly in other exps.
module test_016;

class Foo
{
	this() { return; }

	@property int prop()
	{
		return 5;
	}
}

int main()
{
	auto f = new Foo();
	return f.prop + 1;
}
