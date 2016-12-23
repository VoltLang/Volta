//T compiles:yes
//T retval:17
module test;

import core.object : Object;

interface Fungle
{
	int fanc();
}

interface Fruznab
{
	int sync();
}

interface Foo : Fruznab
{
	int func();
}

class Bar : Foo, Fungle
{
	override int func() {return 17;}
	override int fanc() {return 32;}
	override int sync() {return 22;}
}

int main()
{
	Object obj = new Bar();
	auto f = cast(Foo)obj;
	return f.func();
}
