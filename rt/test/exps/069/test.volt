//T compiles:no
module test;

struct Foo
{
	struct Blarg
	{
	}
}

int main()
{
	auto f = Foo.Blarg + 3;

	return 42;
}
