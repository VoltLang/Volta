//T compiles:yes
//T retval:exception
module test;

import core.object : Object;

struct Foo {
	int y;
}

struct S {
	int x;
	int y;
	void* p;
	int[] a;
	Foo foo;
	Object obj;
	int[int] aa;
	string s;
}

int main()
{
	int[S] aa;
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
	return aa[b];
}

