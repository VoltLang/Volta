module test;

import core.object : Object;

enum SomeEnum { A, B, C}

fn foo(se: SomeEnum)
{
	return;
}

fn foo(obj: Object)
{
	return;
}

fn main() i32
{
	foo(SomeEnum.A);
	return 0;
}

