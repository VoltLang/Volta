//T compiles:no
module test;


abstract class Foo
{
	abstract int x() { return 3; }
}

class Bar : Foo {}

int main()
{
	return 0;
}
