// Properties handled correctly in other exps.
module test;


class Foo
{
	this() { return; }

	@property fn prop() i32
	{
		return 5;
	}
}

int main()
{
	f := new Foo();
	return f.prop - 5;
}
