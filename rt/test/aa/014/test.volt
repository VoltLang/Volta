//T requires:exceptions
// More AA sanity.
module test;

import core.object : Object;
import core.exception : Exception;

struct Foo {
	y: i32;
}

struct S {
	x: i32;
	y: i32;
	foo: Foo;
}

fn main() i32
{
	aa: i32[S];
	S a, b;
	a.x = 1; a.y = 2;
	a.foo.y = 7;
	b.x = 1; b.y = 3;
	b.foo.y = 8;
	aa[a] = 32;
	try {
		return aa[b];
	} catch (Exception) {
		return 0;
	}
	return 1;
}
