//T compiles:yes
//T retval:1
module test;

enum Foo
{
	Baz,
	Bar,
}

int main() {
	Foo val = Foo.Bar;
	switch (cast(int)val) {
	case Foo.Bar:
		return 1;
	default:
		return 9;
	}
}

