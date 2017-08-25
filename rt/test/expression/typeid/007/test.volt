//T macro:expect-failure
//T check:expected lvalue
module test;

interface IFace { fn x(); }

class Clazz : IFace {override fn x() {} }

fn main() i32
{
	c := new Clazz();
	t1 := c.classinfo;
	c.classinfo = t1;
	return 0;
}
