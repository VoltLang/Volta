//T compiles:yes
//T retval:0
module test;

import core.object : Object;

interface IFace { void x(); }

class Clazz : IFace {override void x() {} }

int main()
{
	auto c = new Clazz();
	auto t1 = c.classinfo;
	IFace i = c;
	auto t2 = i.classinfo;
	Object o = c;
	auto t3 = o.classinfo;
	assert(t1 is t2 && t2 is t3);
	return 0;
}
