//T compiles:no
module test;

class Foo
{
	int x;
}

int main()
{
	with (new Foo()) {
		x = 2;
	}
	return 1;
}
