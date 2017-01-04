module test;

import core.object : Object;

class A {}

fn main() i32
{
	o := new Object();
	b := new A();
	if (o.classinfo.base is null && b.classinfo !is null) {
		return 0;
	} else {
		return 1;
	}
}
