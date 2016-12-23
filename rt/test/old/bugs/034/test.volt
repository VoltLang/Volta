//T compiles:yes
//T retval:42
module test;

enum Foo
{
	VAL1 = 2,
	VAL2 = 40,
	VAL3 = 42,
}

enum val = Foo.VAL1 | Foo.VAL2;

int main()
{
	Foo flags = Foo.VAL3;

	return flags & val;
}
