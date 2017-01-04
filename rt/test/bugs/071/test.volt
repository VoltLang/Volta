module test;

import core.object : Object;

fn frozknobble(out obj: Object)
{
	obj2: Object = obj;
}

fn main() i32
{
	obj := new Object();
	frozknobble(out obj);
	return 0;
}

