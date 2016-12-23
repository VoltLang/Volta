//T compiles:yes
//T retval:4
// Setting enum fields.
module test;

enum Foo {
	FOO = 4,
}

class Bar
{
	Foo var;

	void func(Foo a)
	{
		var = a;
		return;
	}
}

int main()
{
	auto b = new Bar();
	b.func(Foo.FOO);

	return cast(int)b.var;
}
