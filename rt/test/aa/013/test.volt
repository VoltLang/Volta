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
	foo: Foo;
}

int main()
{
	aa: i32[S];
	a, b: S;
	a.x = 1; a.y = 2;
	a.foo.y = 7;
	b.x = 1; b.y = 2;
	b.foo.y = 7;
	aa[a] = 32;
	return aa[b] == 32 ? 0 : 1;
}
