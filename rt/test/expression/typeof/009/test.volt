module test;

enum Foo
{
	Bar,
}

int main()
{
	expFoo: Foo;
	expArr: Foo[];
	impFoo := Foo.Bar;
	impArr := [Foo.Bar];

	static is (typeof(expFoo) == Foo);
	static is (typeof(expArr) == Foo[]);
	static is (typeof(impFoo) == Foo);
	static is (typeof(impArr) == Foo[]);

	return 0;
}
