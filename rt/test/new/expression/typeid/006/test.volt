module test;

import core.object : Object;

interface IFace { fn x(); }

class Clazz : IFace {override fn x() {} }

fn main() i32
{
	c := new Clazz();
	t1 := c.classinfo;
	i: IFace = c;
	t2 := i.classinfo;
	o: Object = c;
 	t3 := o.classinfo;
	assert(t1 is t2 && t2 is t3);
	return 0;
}
