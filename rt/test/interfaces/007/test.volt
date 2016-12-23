//T compiles:yes
//T retval:42
module test;

interface Foo
{
	void func();
}

class Bar : Foo
{
	override void func() {}
	void func(int foo) {}
}

int main()
{
	return 42;
}
