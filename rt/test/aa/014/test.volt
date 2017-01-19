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
	p: void*;
	a: i32[];
	foo: Foo;
	obj: Object;
	aa: i32[i32];
	s: string;
}

fn main() i32
{
	aa: i32[S];
	S a, b;
	a.x = 1; a.y = 2; a.p = cast(void*)&a;
	a.a = [1, 1, 3];
	a.foo.y = 7;
	a.obj = new Object();
	a.s = "hello";
	b.x = 1; b.y = 2; b.p = cast(void*)&a;
	b.a = [1, 2, 3];
	b.foo.y = 8;
	b.obj = a.obj;
	b.s = "hell";
	b.s ~= "o";
	aa[a] = 32;
	try {
		return aa[b];
	} catch (Exception) {
		return 0;
	}
	return 1;
}
