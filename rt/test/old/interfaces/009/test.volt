//T compiles:yes
//T retval:17
module test;

interface Foo
{
	int func();
}

class Bar : Foo
{
	override int func() {return 17;}
}

int main()
{
	auto obj = new Bar();
	auto f = cast(Foo)obj;
	return f.func();
}
