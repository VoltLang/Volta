//T compiles:yes
//T retval:3
module test;

import core.object : Object;

interface A {}
interface B {}

class C : A {}
class D : A, B {}

int main()
{
	auto a = new Object();
	auto b = new C();
	auto c = new D();
	return cast(int)(a.classinfo.interfaces.length +
	b.classinfo.interfaces.length +
	c.classinfo.interfaces.length);
}

