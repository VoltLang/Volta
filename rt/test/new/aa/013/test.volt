// AA storing structs sanity test.
module test;

import core.object : Object;

struct Foo
{
	y: i32;
}

struct S {
	x: i32;
	y: i32;
	p: void*;
	a: i32[];
	foo: Foo;;
	obj: Object;
	aa: i32[i32];
	s: string;
}

int main()
{
	aa: i32[S];
	a, b: S;
	a.x = 1; a.y = 2; a.p = cast(void*)&a;
	a.a = [1, 1, 3];
	a.a[1] += 1;
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
	return aa[b] == 32 ? 0 : 1;
}
