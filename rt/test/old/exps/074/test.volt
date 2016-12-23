//T compiles:no
module test;

interface IFace { void x(); }

class Clazz : IFace {override void x() {} }

int main()
{
	auto c = new Clazz();
	auto t1 = c.classinfo;
	c.classinfo = t1;
	return 0;
}
