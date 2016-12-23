//T compiles:yes
//T retval:42
module test;


class Foo
{
}

int main()
{
	auto f = new Foo();

	// Should be able to call implicit constructors.
	f.__ctor();

	return 42;
}
