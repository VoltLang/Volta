module test;

import core.object : Object;

interface Fungle
{
	fn fanc() i32;
}

interface Fruznab
{
	fn sync() i32;
}

interface Foo : Fruznab
{
	fn func() i32;
}

class Bar : Foo, Fungle
{
	override fn func() i32 {return 0;}
	override fn fanc() i32 {return 32;}
	override fn sync() i32 {return 22;}
}

fn main() i32
{
	Object obj = new Bar();
	f := cast(Foo)obj;
	return f.func();
}

