module test;

import core.object : Object;

interface A {}
interface B {}

class C : A {}
class D : A, B {}

fn main() i32
{
	a := new Object();
	b := new C();
	c := new D();
	return (cast(i32)(a.classinfo.interfaces.length +
	b.classinfo.interfaces.length +
	c.classinfo.interfaces.length)) == 3 ? 0 : 1;
}

