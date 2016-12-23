//T compiles:yes
//T retval:42
module test;


class Foo {
	enum ulong err = 4;
}

enum ulong works = 4;

void func(uint) {}

int main()
{
	// This is okay.
	func(works);

	// But not this.
	func(Foo.err);
	return 42;
}
