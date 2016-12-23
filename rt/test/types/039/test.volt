//T compiles:yes
//T retval:42
module test;

enum Foo
{
	Bar,
}

int main()
{
	Foo expFoo;
	Foo[] expArr;
	auto impFoo = Foo.Bar;
	auto impArr = [Foo.Bar];

	static is (typeof(expFoo) == Foo);
	static is (typeof(expArr) == Foo[]);
	static is (typeof(impFoo) == Foo);
	static is (typeof(impArr) == Foo[]);

	return 42;
}
