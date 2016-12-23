//T compiles:yes
//T retval:1
module test;

import core.object : Object;

class A {}

int main()
{
	auto o = new Object();
	auto b = new A();
	if (o.classinfo.base is null && b.classinfo !is null) {
		return 1;
	} else {
		return 0;
	}
}
